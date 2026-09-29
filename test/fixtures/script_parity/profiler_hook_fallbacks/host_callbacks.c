ELISA_WEAK void *elisa_native_callback_ptr(uint8_t *name) { (void)name; return NULL; }
ELISA_WEAK uint32_t elisa_native_callback_call_u32_voidp(uint8_t *name, void *arg, uint32_t fallback) { (void)name; (void)arg; return fallback; }
ELISA_WEAK int32_t elisa_native_callback_call_i32_voidp(uint8_t *name, void *arg, int32_t fallback) { (void)name; (void)arg; return fallback; }
ELISA_WEAK uintptr_t elisa_native_callback_call_usize_voidp(uint8_t *name, void *arg, uintptr_t fallback) { (void)name; (void)arg; return fallback; }
ELISA_WEAK intptr_t elisa_native_callback_call_isize_voidp(uint8_t *name, void *arg, intptr_t fallback) { (void)name; (void)arg; return fallback; }
ELISA_WEAK uint32_t elisa_native_callback_spawn_join_u32_voidp(uint8_t *name, void *arg, uint32_t fallback) { (void)name; (void)arg; return fallback; }
ELISA_WEAK void *elisa_native_callback_context_new_u32_voidp(uint8_t *name, void *arg, uint32_t fallback) { (void)name; (void)arg; (void)fallback; return NULL; }
ELISA_WEAK void *elisa_native_callback_context_entry_u32_voidp(void) { return NULL; }
ELISA_WEAK int32_t elisa_native_callback_context_start_u32_voidp(void *ctx, uintptr_t *thread) { (void)ctx; (void)thread; return -1; }
ELISA_WEAK uint32_t elisa_native_callback_context_join_u32_voidp(uintptr_t handle, void *ctx, uint32_t fallback) { (void)handle; (void)ctx; return fallback; }
ELISA_WEAK uint32_t elisa_native_callback_context_spawn_join_u32_voidp(void *ctx, uint32_t fallback) { (void)ctx; return fallback; }
ELISA_WEAK uint32_t elisa_native_callback_context_result_u32(void *ctx, uint32_t fallback) { (void)ctx; return fallback; }
ELISA_WEAK void elisa_native_callback_context_free(void *ctx) { (void)ctx; }
ELISA_WEAK void *va_copy(void *source) { return source; }
ELISA_WEAK void va_end(void *argument) { (void)argument; }
