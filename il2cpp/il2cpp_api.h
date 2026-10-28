// Copyright (c) 2026 zexisyy. All rights reserved.
#pragma once
#include <stddef.h>
#include <string.h>
#include <dlfcn.h>

typedef void *(*il2cpp_domain_get_t)();
typedef void **(*il2cpp_domain_get_assemblies_t)(void *domain, size_t *size);
typedef void *(*il2cpp_assembly_get_image_t)(void *assembly);
typedef const char *(*il2cpp_image_get_name_t)(void *image);
typedef void *(*il2cpp_class_from_name_t)(void *image, const char *nameSpace, const char *name);
typedef void *(*il2cpp_object_new_t)(void *klass);

static void *UnitySym(const char *name) {
    return dlsym(RTLD_DEFAULT, name);
}

static void *FindGameClass(const char *nameSpace, const char *name) {
    auto domain_get = (il2cpp_domain_get_t)UnitySym("il2cpp_domain_get");
    auto domain_get_assemblies = (il2cpp_domain_get_assemblies_t)UnitySym("il2cpp_domain_get_assemblies");
    auto assembly_get_image = (il2cpp_assembly_get_image_t)UnitySym("il2cpp_assembly_get_image");
    auto image_get_name = (il2cpp_image_get_name_t)UnitySym("il2cpp_image_get_name");
    auto class_from_name = (il2cpp_class_from_name_t)UnitySym("il2cpp_class_from_name");
    if (!domain_get || !domain_get_assemblies || !assembly_get_image || !image_get_name || !class_from_name)
        return nullptr;
    size_t count = 0;
    void **assemblies = domain_get_assemblies(domain_get(), &count);
    if (!assemblies) return nullptr;
    for (size_t i = 0; i < count; i++) {
        void *image = assembly_get_image(assemblies[i]);
        const char *imageName = image ? image_get_name(image) : nullptr;
        if (imageName && strstr(imageName, "Assembly-CSharp"))
            return class_from_name(image, nameSpace, name);
    }
    return nullptr;
}