#include "hook/hook.h"
#include "hook/mach_excServer.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <mach-o/dyld_images.h>
#include <mach-o/nlist.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/sysctl.h>

#define MAX_HOOKS 16

/* ============================================================================
 * Mach exception callbacks — BẮT BUỘC phải có để mach_exc_server compile
 * ========================================================================== */

kern_return_t catch_mach_exception_raise(
    mach_port_t exception_port,
    mach_port_t thread,
    mach_port_t task,
    exception_type_t exception,
    mach_exception_data_t code,
    mach_msg_type_number_t codeCnt) {
    abort();
}

kern_return_t catch_mach_exception_raise_state_identity(
    mach_port_t exception_port,
    mach_port_t thread,
    mach_port_t task,
    exception_type_t exception,
    mach_exception_data_t code,
    mach_msg_type_number_t codeCnt,
    int *flavor,
    thread_state_t old_state,
    mach_msg_type_number_t old_stateCnt,
    thread_state_t new_state,
    mach_msg_type_number_t *new_stateCnt) {
    abort();
}

/* ============================================================================
 * Global state
 * ========================================================================== */

mach_port_t server;

struct hook {
    uintptr_t address;
    uintptr_t function;
};
static struct hook hooks[MAX_HOOKS];
static int active_hooks = 0;

/* ============================================================================
 * Exception handler chính — nhận breakpoint, redirect PC sang hàm hooked
 * ========================================================================== */

kern_return_t catch_mach_exception_raise_state(
    mach_port_t exception_port,
    exception_type_t exception,
    const mach_exception_data_t code,
    mach_msg_type_number_t codeCnt,
    int *flavor,
    const thread_state_t old_state,
    mach_msg_type_number_t old_stateCnt,
    thread_state_t new_state,
    mach_msg_type_number_t *new_stateCnt) {
    arm_thread_state64_t *address  = (arm_thread_state64_t *)old_state;
    arm_thread_state64_t *function = (arm_thread_state64_t *)new_state;

    for (int i = 0; i < active_hooks; ++i) {
        if (hooks[i].address == arm_thread_state64_get_pc(*address)) {
            *function = *address;
            *new_stateCnt = old_stateCnt;
            arm_thread_state64_set_pc_fptr(*function, hooks[i].function);
            return KERN_SUCCESS;
        }
    }
    return KERN_FAILURE;
}

/* ============================================================================
 * Thread chạy mach_msg_server để bắt exception
 * ========================================================================== */

void *exception_handler(void *unused) {
    mach_msg_server(mach_exc_server,
                    sizeof(union __RequestUnion__catch_mach_exc_subsystem),
                    server, MACH_MSG_OPTION_NONE);
    abort();
}

/* ============================================================================
 * Helper: ghi TOÀN BỘ danh sách breakpoint hiện tại vào CPU + MỌI thread
 * ========================================================================== */

static bool apply_debug_state(void) {
    arm_debug_state64_t state = {};

    /* Build state từ TẤT CẢ hook đang active — đây là điểm cốt lõi của fix */
    for (int i = 0; i < active_hooks; i++) {
        state.__bvr[i] = hooks[i].address;
        state.__bcr[i] = 0x1e5;   /* enable + user mode + match on instruction */
    }

    /* Set cho task (main thread) */
    if (task_set_state(mach_task_self(), ARM_DEBUG_STATE64,
                       (thread_state_t)&state, ARM_DEBUG_STATE64_COUNT) != KERN_SUCCESS) {
        printf("[hook] task_set_state FAILED\n");
        fflush(stdout);
        return false;
    }

    /* Set cho tất cả thread đang chạy */
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t thread_count = 0;
    if (task_threads(mach_task_self(), &threads, &thread_count) != KERN_SUCCESS) {
        printf("[hook] task_threads FAILED\n");
        fflush(stdout);
        return false;
    }

    bool success = true;
    for (int i = 0; i < (int)thread_count; ++i) {
        if (thread_set_state(threads[i], ARM_DEBUG_STATE64,
                             (thread_state_t)&state, ARM_DEBUG_STATE64_COUNT) != KERN_SUCCESS) {
            success = false;
        }
    }

    for (int i = 0; i < (int)thread_count; ++i)
        mach_port_deallocate(mach_task_self(), threads[i]);
    vm_deallocate(mach_task_self(), (vm_address_t)threads,
                  thread_count * sizeof(*threads));

    return success;
}

/* ============================================================================
 * API chính: hook() — APPEND thay vì overwrite
 * ========================================================================== */

bool hook(void *address[], void *function[], int count) {
    static bool initialized = false;
    static int breakpoints = 6;

    if (!initialized) {
        size_t size = sizeof(breakpoints);
        sysctlbyname("hw.optional.breakpoint", &breakpoints, &size, NULL, 0);
        if (breakpoints <= 0 || breakpoints > 16) breakpoints = 6;

        printf("[hook] INIT: max breakpoints = %d\n", breakpoints);
        fflush(stdout);

        /* Tạo exception port */
        mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &server);
        mach_port_insert_right(mach_task_self(), server, server, MACH_MSG_TYPE_MAKE_SEND);
        task_set_exception_ports(mach_task_self(), EXC_MASK_BREAKPOINT, server,
                                 EXCEPTION_STATE | MACH_EXCEPTION_CODES,
                                 ARM_THREAD_STATE64);

        /* Thread bắt exception */
        pthread_t thread;
        pthread_create(&thread, NULL, exception_handler, NULL);
        pthread_detach(thread);

        initialized = true;
    }

    if (count <= 0) return false;

    /* Check tổng (hook cũ + hook mới) có vượt phần cứng không */
    if (active_hooks + count > breakpoints) {
        printf("[hook] OUT OF BREAKPOINTS: have=%d want=%d max=%d\n",
               active_hooks, count, breakpoints);
        fflush(stdout);
        return false;
    }
    if (active_hooks + count > MAX_HOOKS) {
        printf("[hook] ARRAY FULL\n");
        fflush(stdout);
        return false;
    }

    printf("[hook] CALLED: count=%d, active_before=%d\n", count, active_hooks);

    /* APPEND — KHÔNG ghi đè từ index 0 */
    for (int i = 0; i < count; i++) {
        hooks[active_hooks + i] = (struct hook){
            (uintptr_t)address[i],
            (uintptr_t)function[i]
        };
        printf("[hook]   reg[%d] addr=%p -> fn=%p\n",
               active_hooks + i, address[i], function[i]);
    }
    active_hooks += count;

    /* Rebuild full state với TẤT CẢ hook */
    bool ok = apply_debug_state();
    printf("[hook] DONE: active_after=%d, success=%d\n", active_hooks, ok);
    fflush(stdout);

    return ok;
}

/* ============================================================================
 * unhook() — xóa hook theo địa chỉ, rebuild lại state
 * ========================================================================== */

bool unhook(void *address) {
    int newCount = 0;
    for (int i = 0; i < active_hooks; ++i) {
        if ((void *)hooks[i].address != address) {
            hooks[newCount++] = hooks[i];
        }
    }
    active_hooks = newCount;

    printf("[hook] UNHOOK: active_after=%d\n", active_hooks);
    fflush(stdout);

    return apply_debug_state();
}