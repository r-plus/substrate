#ifndef SUBSTRATE_H_
#define SUBSTRATE_H_

extern "C" {
    #include <mach-o/nlist.h>
}

#include <objc/runtime.h>
#include <dlfcn.h>

void MSHookFunction(void *symbol, void *replace, void **result);
void MSHookMessage(Class _class, SEL sel, IMP imp, const char *prefix);

#ifdef __cplusplus

template <typename Type_>
static inline void MSHookFunction(Type_ *symbol, Type_ *replace, Type_ **result) {
    return MSHookFunction(
        reinterpret_cast<void *>(symbol),
        reinterpret_cast<void *>(replace),
        reinterpret_cast<void **>(result)
    );
}

template <typename Type_>
static inline void MSHookFunction(Type_ *symbol, Type_ *replace) {
    return MSHookFunction(symbol, replace, reinterpret_cast<Type_ **>(NULL));
}

#endif

#define Foundation "/System/Library/Frameworks/Foundation.framework/Foundation"
#define UIKit "/System/Library/Frameworks/UIKit.framework/UIKit"

#endif//SUBSTRATE_H_
