#ifndef __VR_HOOK_H__
#define __VR_HOOK_H__

#ifdef _EXPORTING
#define DECLSPEC    __declspec(dllexport)
#else
#define DECLSPEC    __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif
  
void DECLSPEC ClearHook();
int DECLSPEC SetHook(HWND hwnd, UINT msg);

#ifdef __cplusplus
}
#endif

#endif /* __VR_HOOK_H__ */

