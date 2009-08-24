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
#include <objc/message.h>
#include <dlfcn.h>

#define _finline \
    inline __attribute__((always_inline))
#define _disused \
    __attribute__((unused))

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

namespace etl {

template <unsigned Case_>
struct Case {
    static char value[Case_ + 1];
};

typedef Case<true> Yes;
typedef Case<false> No;

namespace be {
    template <typename Checked_>
    static Yes CheckClass_(void (Checked_::*)());

    template <typename Checked_>
    static No CheckClass_(...);
}

template <typename Type_>
struct IsClass {
    void gcc32();

    static const bool value = (sizeof(be::CheckClass_<Type_>(0).value) == sizeof(Yes::value));
};

}

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

#define MSMessageHook_(type, _class, name, dollar, colon, call, args...) \
    static type _$ ## name ## $ ## dollar(Class _cls, type (*_old)(_class, SEL, ## args), type (*_spr)(struct objc_super *, SEL, ## args), _class self, SEL _cmd, ## args); \
    MSHook(type, name ## $ ## dollar, _class self, SEL _cmd, ## args) { \
        Class const _cls($ ## name); \
        type (* const _old)(_class, SEL, ## args) = _ ## name ## $ ## dollar; \
        type (*_spr)(struct objc_super *, SEL, ## args) = ::etl::IsClass<type>::value ? reinterpret_cast<type (*)(struct objc_super *, SEL, ## args)>(&objc_msgSendSuper_stret) : reinterpret_cast<type (*)(struct objc_super *, SEL, ## args)>(&objc_msgSendSuper); \
        return _$ ## name ## $ ## dollar call; \
    } \
    static class C_$ ## name ## $ ## dollar { public: _finline C_$ ## name ## $ ##dollar() { \
        MSHookMessage($ ## name, @selector(colon), MSHake(name ## $ ## dollar)); \
    } } V_$ ## dollar; \
    static _finline type _$ ## name ## $ ## dollar(Class _cls, type (*_old)(_class, SEL, ## args), type (*_spr)(struct objc_super *, SEL, ## args), _class self, SEL _cmd, ## args)

/* for((x=1;x!=7;++x)){ echo -n "#define MSMessageHook${x}_(type, _class, name";for((y=0;y!=x;++y));do echo -n ", sel$y";done;for((y=0;y!=x;++y));do echo -n ", type$y, arg$y";done;echo ") \\";echo -n "    MSMessageHook_(type, _class, name,";for((y=0;y!=x;++y));do if [[ $y -ne 0 ]];then echo -n " ##";fi;echo -n " sel$y ## $";done;echo -n ", ";for((y=0;y!=x;++y));do echo -n "sel$y:";done;echo -n ", (_cls, _old, _spr, self, _cmd";for((y=0;y!=x;++y));do echo -n ", arg$y";done;echo -n ")";for((y=0;y!=x;++y));do echo -n ", type$y arg$y";done;echo ")";} */

#define MSMessageHook0_(type, _class, name, sel0) \
    MSMessageHook_(type, _class, name, sel0, sel0, (_cls, _old, _spr, self, _cmd))
#define MSMessageHook1_(type, _class, name, sel0, type0, arg0) \
    MSMessageHook_(type, _class, name, sel0 ## $, sel0:, (_cls, _old, _spr, self, _cmd, arg0), type0 arg0)
#define MSMessageHook2_(type, _class, name, sel0, sel1, type0, arg0, type1, arg1) \
    MSMessageHook_(type, _class, name, sel0 ## $ ## sel1 ## $, sel0:sel1:, (_cls, _old, _spr, self, _cmd, arg0, arg1), type0 arg0, type1 arg1)
#define MSMessageHook3_(type, _class, name, sel0, sel1, sel2, type0, arg0, type1, arg1, type2, arg2) \
    MSMessageHook_(type, _class, name, sel0 ## $ ## sel1 ## $ ## sel2 ## $, sel0:sel1:sel2:, (_cls, _old, _spr, self, _cmd, arg0, arg1, arg2), type0 arg0, type1 arg1, type2 arg2)
#define MSMessageHook4_(type, _class, name, sel0, sel1, sel2, sel3, type0, arg0, type1, arg1, type2, arg2, type3, arg3) \
    MSMessageHook_(type, _class, name, sel0 ## $ ## sel1 ## $ ## sel2 ## $ ## sel3 ## $, sel0:sel1:sel2:sel3:, (_cls, _old, _spr, self, _cmd, arg0, arg1, arg2, arg3), type0 arg0, type1 arg1, type2 arg2, type3 arg3)
#define MSMessageHook5_(type, _class, name, sel0, sel1, sel2, sel3, sel4, type0, arg0, type1, arg1, type2, arg2, type3, arg3, type4, arg4) \
    MSMessageHook_(type, _class, name, sel0 ## $ ## sel1 ## $ ## sel2 ## $ ## sel3 ## $ ## sel4 ## $, sel0:sel1:sel2:sel3:sel4:, (_cls, _old, _spr, self, _cmd, arg0, arg1, arg2, arg3, arg4), type0 arg0, type1 arg1, type2 arg2, type3 arg3, type4 arg4)
#define MSMessageHook6_(type, _class, name, sel0, sel1, sel2, sel3, sel4, sel5, type0, arg0, type1, arg1, type2, arg2, type3, arg3, type4, arg4, type5, arg5) \
    MSMessageHook_(type, _class, name, sel0 ## $ ## sel1 ## $ ## sel2 ## $ ## sel3 ## $ ## sel4 ## $ ## sel5 ## $, sel0:sel1:sel2:sel3:sel4:sel5:, (_cls, _old, _spr, self, _cmd, arg0, arg1, arg2, arg3, arg4, arg5), type0 arg0, type1 arg1, type2 arg2, type3 arg3, type4 arg4, type5 arg5)

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

#define MSOldCall(args...) \
    _old(self, _cmd, ## args)
#define MSSuperCall(args...) \
    _spr(& (struct objc_super) {self, class_getSuperclass(_cls)}, _cmd, ## args)

#define MSIvar(type, name) \
    type &name(MSHookIvar<type>(self, #name))

#define MSHookClass(name) \
    static Class $ ## name = objc_getClass(#name);
#define MSHookMetaClass(name) \
    static Class $$ ## name = object_getClass($ ## name);

#endif

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
