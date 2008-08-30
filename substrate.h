#ifndef SUBSTRATE_H_
#define SUBSTRATE_H_

void MSHookFunction(void *symbol, void *replace, void **result);
void MSHookMessage(Class _class, SEL sel, IMP imp, const char *prefix);

#endif//SUBSTRATE_H_
