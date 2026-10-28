// Copyright (c) 2026 zexisyy. All rights reserved.
// 
// Wrapper để tương thích với code tác giả (aimkill.h, send108.h, il2cpp_api.h đều #include "getbase.h").
// Thực tế dùng Helper/Mem.h vì source đã có sẵn getRealOffset / getBaseInfo / getRealOffsetNULL.
// Tránh redefine struct MemoryFileInfo và các hàm static khi include cùng Mem.h.

#pragma once
#include "Helper/Mem.h"