#pragma once

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

void InitAntiCheatBypass(void);
void InitAntiCheatBypassForce(void);

bool ACBypass_IsInitialized(void);
int ACBypass_HooksTotal(void);
int ACBypass_HooksSucceeded(void);

bool ACBypass_StaticPatchEnabled(void);
void ACBypass_SetStaticPatchEnabled(bool enabled);

bool ACBypass_UnityPatchStarted(void);
bool ACBypass_UnityPatchFinished(void);

void ACBypass_PatchUnityFrameworkOnce(void);
void ACBypass_RunBypass(void);

void ACBypass_NotifyStatusChanged(void);

#ifdef __OBJC__
#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *const kACBypassStatusChangedNotification;
NSString *ACBypass_StatusSummary(void);
#endif

#ifdef __cplusplus
}
#endif