#ifndef SUBSTRATE_H_
#define SUBSTRATE_H_

#ifdef __cplusplus
extern "C" {
#endif
    #include <mach-o/nlist.h>
#ifdef __cplusplus
}
#endif

#include <objc/runtime.h>
//#include <objc/message.h>
#include <dlfcn.h>

#ifdef __cplusplus
#define _default(value) = value
#else
#define _default(value)
#endif

#ifdef __cplusplus
extern "C" {
#endif

void MSHookFunction(void *symbol, void *replace, void **result);
IMP MSHookMessage(Class _class, SEL sel, IMP imp, const char *prefix _default(NULL));
void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result);

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus

template <typename Type_>
static inline Type_ *MSHookMessage(Class _class, SEL sel, Type_ *imp, const char *prefix = NULL) {
    return reinterpret_cast<Type_ *>(MSHookMessage(_class, sel, reinterpret_cast<IMP>(imp), prefix));
}

template <typename Type_>
static inline void MSHookMessage(Class _class, SEL sel, Type_ *imp, Type_ **result) {
    return MSHookMessageEx(_class, sel, reinterpret_cast<IMP>(imp), reinterpret_cast<IMP *>(result));
}

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

template <typename Type_>
static inline void MSHookSymbol(Type_ *&value, const char *name, void *handle) {
    value = reinterpret_cast<Type_ *>(dlsym(handle, name));
}

template <typename Type_>
static inline Type_ &MSHookIvar(id self, const char *name) {
    Ivar ivar(class_getInstanceVariable(object_getClass(self), name));
    void *pointer(ivar == NULL ? NULL : reinterpret_cast<char *>(self) + ivar_getOffset(ivar));
    return *reinterpret_cast<Type_ *>(pointer);
}

#define MSHookMessage0(_class, arg0) \
    MSHookMessage($ ## _class, @selector(arg0), MSHake(_class ## $ ## arg0))
#define MSHookMessage1(_class, arg0) \
    MSHookMessage($ ## _class, @selector(arg0:), MSHake(_class ## $ ## arg0 ## $))
#define MSHookMessage2(_class, arg0, arg1) \
    MSHookMessage($ ## _class, @selector(arg0:arg1:), MSHake(_class ## $ ## arg0 ## $ ## arg1 ## $))
#define MSHookMessage3(_class, arg0, arg1, arg2) \
    MSHookMessage($ ## _class, @selector(arg0:arg1:arg2:), MSHake(_class ## $ ## arg0 ## $ ## arg1 ## $ ## arg2 ## $))
#define MSHookMessage4(_class, arg0, arg1, arg2, arg3) \
    MSHookMessage($ ## _class, @selector(arg0:arg1:arg2:arg3:), MSHake(_class ## $ ## arg0 ## $ ## arg1 ## $ ## arg2 ## $ ## arg3 ## $))
#define MSHookMessage5(_class, arg0, arg1, arg2, arg3, arg4) \
    MSHookMessage($ ## _class, @selector(arg0:arg1:arg2:arg3:arg4:), MSHake(_class ## $ ## arg0 ## $ ## arg1 ## $ ## arg2 ## $ ## arg3 ## $ ## arg4 ## $))
#define MSHookMessage6(_class, arg0, arg1, arg2, arg3, arg4, arg5) \
    MSHookMessage($ ## _class, @selector(arg0:arg1:arg2:arg3:arg4:arg5:), MSHake(_class ## $ ## arg0 ## $ ## arg1 ## $ ## arg2 ## $ ## arg3 ## $ ## arg4 ## $ ## arg5 ## $))

#define MSMessageHook_(type, _class, name, dollar, colon, args...) \
    MSHook(type, name ## $ ## dollar, _class self, SEL _cmd, ## args); \
    static class C_$ ## name ## $ ## dollar { public: C_$ ## name ## $ ##dollar() { \
        MSHookMessage($ ## name, @selector(colon), MSHake(name ## $ ## dollar)); \
    } } V_$ ## dollar; \
    static type $ ## name ## $ ## dollar(_class self, SEL _cmd, ## args)

#define MSMessageHook0_(type, _class, name, arg0, args...) \
    MSMessageHook_(type, _class, name, arg0, arg0, ## args)
#define MSMessageHook1_(type, _class, name, arg0, args...) \
    MSMessageHook_(type, _class, name, arg0 ## $, arg0:, ## args)
#define MSMessageHook2_(type, _class, name, arg0, arg1, args...) \
    MSMessageHook_(type, _class, name, arg0 ## $ ## arg1 ## $, arg0:arg1:, ## args)
#define MSMessageHook3_(type, _class, name, arg0, arg1, arg2, args...) \
    MSMessageHook_(type, _class, name, arg0 ## $ ## arg1 ## $ ## arg2 ## $, arg0:arg1:arg2:, ## args)
#define MSMessageHook4_(type, _class, name, arg0, arg1, arg2, arg3, args...) \
    MSMessageHook_(type, _class, name, arg0 ## $ ## arg1 ## $ ## arg2 ## $ ## arg3 ## $, arg0:arg1:arg2:arg3:, ## args)
#define MSMessageHook5_(type, _class, name, arg0, arg1, arg2, arg3, arg4, args...) \
    MSMessageHook_(type, _class, name, arg0 ## $ ## arg1 ## $ ## arg2 ## $ ## arg3 ## $ ## arg4 ## $, arg0:arg1:arg2:arg3:arg4:, ## args)
#define MSMessageHook6_(type, _class, name, arg0, arg1, arg2, arg3, arg4, arg5, args...) \
    MSMessageHook_(type, _class, name, arg0 ## $ ## arg1 ## $ ## arg2 ## $ ## arg3 ## $ ## arg4 ## $ ## arg5 ## $, arg0:arg1:arg2:arg3:arg4:arg5:, ## args)

#define MSMessageHook0(type, _class, args...) MSMessageHook0_(type, _class *, _class, ## args)
#define MSMessageHook1(type, _class, args...) MSMessageHook1_(type, _class *, _class, ## args)
#define MSMessageHook2(type, _class, args...) MSMessageHook2_(type, _class *, _class, ## args)
#define MSMessageHook3(type, _class, args...) MSMessageHook3_(type, _class *, _class, ## args)
#define MSMessageHook4(type, _class, args...) MSMessageHook4_(type, _class *, _class, ## args)
#define MSMessageHook5(type, _class, args...) MSMessageHook5_(type, _class *, _class, ## args)
#define MSMessageHook6(type, _class, args...) MSMessageHook6_(type, _class *, _class, ## args)

#define MSMetaMessageHook0(type, _class, args...) MSMessageHook0_(type, Class, $ ## _class, ## args)
#define MSMetaMessageHook1(type, _class, args...) MSMessageHook1_(type, Class, $ ## _class, ## args)
#define MSMetaMessageHook2(type, _class, args...) MSMessageHook2_(type, Class, $ ## _class, ## args)
#define MSMetaMessageHook3(type, _class, args...) MSMessageHook3_(type, Class, $ ## _class, ## args)
#define MSMetaMessageHook4(type, _class, args...) MSMessageHook4_(type, Class, $ ## _class, ## args)
#define MSMetaMessageHook5(type, _class, args...) MSMessageHook5_(type, Class, $ ## _class, ## args)
#define MSMetaMessageHook6(type, _class, args...) MSMessageHook6_(type, Class, $ ## _class, ## args)

#define MSCall0(name, arg0, args...) \
    _ ## name ## $ ## arg0(self, _cmd, ## args)
#define MSCall1(name, arg0, args...) \
    _ ## name ## $ ## arg0 ## $(self, _cmd, ## args)
#define MSCall2(name, arg0, arg1, args...) \
    _ ## name ## $ ## arg0 ## $ ## arg1 ## $(self, _cmd, ## args)
#define MSCall3(name, arg0, arg1, arg2, args...) \
    _ ## name ## $ ## arg0 ## $ ## arg1 ## $ ## arg2 ## $(self, _cmd, ## args)
#define MSCall4(name, arg0, arg1, arg2, arg3, args...) \
    _ ## name ## $ ## arg0 ## $ ## arg1 ## $ ## arg2 ## $ ## arg3 ## $(self, _cmd, ## args)
#define MSCall5(name, arg0, arg1, arg2, arg3, arg4, args...) \
    _ ## name ## $ ## arg0 ## $ ## arg1 ## $ ## arg2 ## $ ## arg3 ## $ ## arg4 ## $(self, _cmd, ## args)
#define MSCall6(name, arg0, arg1, arg2, arg3, arg4, arg5, args...) \
    _ ## name ## $ ## arg0 ## $ ## arg1 ## $ ## arg2 ## $ ## arg3 ## $ ## arg4 ## $ ## arg5 ## $(self, _cmd, ## args)

#define MSIvar(type, name) \
    type &name(MSHookIvar<type>(self, #name))

#endif

#define MSHookClass(name) \
    static Class $ ## name = objc_getClass(#name);
#define MSHookMetaClass(name) \
    static Class $$ ## name = object_getClass($ ## name);

#define MSHook(type, name, args...) \
    static type (*_ ## name)(args); \
    static type $ ## name(args)

#define MSHake(name) \
    &$ ## name, &_ ## name

#define Foundation_f "/System/Library/Frameworks/Foundation.framework/Foundation"
#define UIKit_f "/System/Library/Frameworks/UIKit.framework/UIKit"
#define JavaScriptCore_f "/System/Library/PrivateFrameworks/JavaScriptCore.framework/JavaScriptCore"
#define IOKit_f "/System/Library/Frameworks/IOKit.framework/IOKit"

#endif//SUBSTRATE_H_
