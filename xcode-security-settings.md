# Xcode Security Settings

Security build settings decisions for LearnAlert.

## Enabled settings

- `ENABLE_ENHANCED_SECURITY`: Enabled at project level to enable Apple's Enhanced Security runtime protections, pointer authentication, typed allocators, and memory safety.
- `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE`: Enabled on `LearnAlert` to generate the `arm64e.x1` slice required for hardware-checked pointer arithmetic overflow checking.
- `com.apple.security.hardened-process`: Enabled in `LearnAlert.entitlements`.
- `com.apple.security.hardened-process.enhanced-security-version-string` to `2`: Version 2 enhanced security runtime protections.
- `com.apple.security.hardened-process.hardened-heap`: Hardened heap with type-isolated buckets.
- `com.apple.security.hardened-process.dyld-ro`: Read-only dynamic linker state.
- `com.apple.security.hardened-process.platform-restrictions-string` to `2`: Runtime dyld and Mach messaging restrictions.
- `com.apple.security.hardened-process.checked-allocations`: Hardware Memory Tagging (MTE) runtime protection.
- `com.apple.security.hardened-process.checked-allocations.soft-mode`: Soft mode for non-fatal hardware memory tagging evaluation.
- `com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow`: Run time enforcement of checked pointer arithmetic.

## Disabled settings

None.

## Deferred

- `Additional diagnostic settings`: Extra opt-in warnings and analyzers beyond standard defaults deferred for later evaluation.
