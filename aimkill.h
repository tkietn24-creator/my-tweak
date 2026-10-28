// AimkillSend.h — code tác giả zexisyy, message 106
#pragma once
#include <stdint.h>
#include <math.h>
#include "Helper/Mem.h"
#include "il2cpp/il2cpp_api.h"

struct COW_GamePlay_IHAAMHPPLMG_o {
    uint32_t m_Value;
    uint32_t m_ID;
    uint8_t  m_TeamID;
    uint8_t  m_ShortID;
    uint64_t m_IDMask;
};

struct message_PVector3IntPos_o {
    void *klass;
    void *monitor;
    bool UDPClientMessageBase_m_GetFromPool;
    int32_t X;
    int32_t Y;
    int32_t Z;
};

struct message_C2S_RUDP_TakeDamage_Req_o2 {
    void *klass;
    void *monitor;
    bool UDPClientMessageBase_m_GetFromPool;
    uint32_t AttackableEntityID;
    uint16_t RealDamageValue;
    uint16_t ShieldDamageValue;
    uint32_t DamageValue;
    uint32_t DamagerID;
    int32_t  WeaponDataID;
    uint32_t WeaponUniqueID;
    uint8_t  HitBodyPart;
    uint32_t TickCount;
    message_PVector3IntPos_o *FirePos;
    message_PVector3IntPos_o *TargetPos;
    void *CheckParams;
    uint32_t ExtraData;
    float ArmorRatio;
    uint64_t ExtraFlag;
    int8_t SpecialHitType;
    bool ForceNoHeadShot;
    bool IsPlayerBackArea;
    void *DamageData;
    float BaseTime;
    bool ManualReload;
};

#define OFF_Zexis_TakeDamageMsgId                 106
#define OFF_Zexis_GameFacade_Send                 0x5926D78
#define OFF_Zexis_GetWeaponOnHand                 0x5616118
#define OFF_Zexis_GetItemDataID                   0x5B0B8EC
#define OFF_Zexis_Weapon_Field5F0                 0x5F0
#define OFF_Zexis_Weapon_BaseDamageField          0xA8
#define OFF_Zexis_Weapon_UniqueNetID              0x10
#define OFF_Zexis_Weapon_Range                    0x5BED0A8
#define OFF_Zexis_Player_ObjectPool               0xE50
#define OFF_Zexis_Player_PlayerID                 0x408
#define OFF_Zexis_Player_Attributes               0x768
#define OFF_Zexis_Player_DamageModule             0x318
#define OFF_Zexis_Player_DamageInfo               0x10
#define OFF_Zexis_Player_AimTarget                0x738
#define OFF_Zexis_DamageInfo_DamageValue          0x10
#define OFF_Zexis_DamageInfo_HitPart              0x14
#define OFF_Zexis_DamageInfo_AttackerID           0x28
#define OFF_Zexis_DamageInfo_Weapon               0x40
#define OFF_Zexis_Pool_HitGameObject              0x18
#define OFF_Zexis_Pool_HitCollider                0x20
#define OFF_Zexis_Pool_HitLocation                0x28
#define OFF_Zexis_Pool_RayDir                     0x34
#define OFF_Zexis_Pool_RayDir2                    0x40
#define OFF_Zexis_Pool_StartPos                   0x4C
#define OFF_Zexis_Pool_Damage                     0x58
#define OFF_Zexis_Pool_Distance                   0x5C
#define OFF_Zexis_Pool_Flags60                    0x60
#define OFF_Zexis_Pool_Flags64                    0x64
#define OFF_Zexis_Pool_Flag70                     0x70
#define OFF_Zexis_Pool_Flag71                     0x71
#define OFF_Zexis_GetHeadCollider                 0x5634F3C
#define OFF_Zexis_GetGameObject                   0x8D59C7C
#define OFF_Zexis_GetAimingEntity                 0x56A7F5C
#define OFF_Zexis_BuildCheckParams                0x5C262DC
#define OFF_Zexis_WeaponDoSomething               0x5C2B3F0
#define OFF_Zexis_StartFiring                     0x5A5B868
#define OFF_Zexis_StopFire                        0x5A5C464
#define OFF_Zexis_CurrentGameSimulationTimer      0x5919E58
#define OFF_Zexis_SimTimer_TickCount              0x20
#define OFF_Zexis_CreateDamageReq                 0x607E1DC
#define OFF_Zexis_GetPlayerID                     0x55FE154
#define OFF_Zexis_PlayerIDToUint                  0x649046C
#define OFF_Zexis_PackVector3                     0x3715AC4
#define OFF_Zexis_RealtimeSinceStartup            0x8D667EC

static void *g_dmg99 = nullptr;

// ── Cached function pointers (nhanh hơn getRealOffset mỗi frame) ──
namespace AimKillCache {
    static void *(*getWeaponOnHand)(void *) = nullptr;
    static int   (*getItemDataID)(void *) = nullptr;
    static void *(*getHeadCollider)(void *) = nullptr;
    static void *(*getGameObject)(void *) = nullptr;
    static float (*getRange)(void *) = nullptr;
    static void *(*getAimingEntity)(void *, void *) = nullptr;
    static void *(*buildCheckParams)(void *, void *, void *, bool, void *) = nullptr;
    static void  (*weaponDoSomething)(void *, void *, uint32_t) = nullptr;
    static void  (*startFiring)(void *, void *) = nullptr;
    static void  (*stopFire)(void *, void *) = nullptr;
    static void *(*currentSimTimer)(void *) = nullptr;
    static void *(*createDamageReq)(void *) = nullptr;
    static COW_GamePlay_IHAAMHPPLMG_o (*getPlayerID)(void *) = nullptr;
    static uint32_t (*playerIDToUint)(COW_GamePlay_IHAAMHPPLMG_o) = nullptr;
    static void *(*packVector3)(Vector3) = nullptr;
    static float (*realtimeSinceStartup)() = nullptr;
    static bool  (*gameFacadeSend)(uint32_t, void *, uint8_t, bool) = nullptr;

    static inline void initOnce() {
        if (gameFacadeSend) return;   // đã init
        getWeaponOnHand     = (void *(*)(void *))getRealOffset(OFF_Zexis_GetWeaponOnHand);
        getItemDataID       = (int   (*)(void *))getRealOffset(OFF_Zexis_GetItemDataID);
        getHeadCollider     = (void *(*)(void *))getRealOffset(OFF_Zexis_GetHeadCollider);
        getGameObject       = (void *(*)(void *))getRealOffset(OFF_Zexis_GetGameObject);
        getRange            = (float (*)(void *))getRealOffset(OFF_Zexis_Weapon_Range);
        getAimingEntity     = (void *(*)(void *, void *))getRealOffset(OFF_Zexis_GetAimingEntity);
        buildCheckParams    = (void *(*)(void *, void *, void *, bool, void *))getRealOffset(OFF_Zexis_BuildCheckParams);
        weaponDoSomething   = (void  (*)(void *, void *, uint32_t))getRealOffset(OFF_Zexis_WeaponDoSomething);
        startFiring         = (void  (*)(void *, void *))getRealOffset(OFF_Zexis_StartFiring);
        stopFire            = (void  (*)(void *, void *))getRealOffset(OFF_Zexis_StopFire);
        currentSimTimer     = (void *(*)(void *))getRealOffset(OFF_Zexis_CurrentGameSimulationTimer);
        createDamageReq     = (void *(*)(void *))getRealOffset(OFF_Zexis_CreateDamageReq);
        getPlayerID         = (COW_GamePlay_IHAAMHPPLMG_o (*)(void *))getRealOffset(OFF_Zexis_GetPlayerID);
        playerIDToUint      = (uint32_t (*)(COW_GamePlay_IHAAMHPPLMG_o))getRealOffset(OFF_Zexis_PlayerIDToUint);
        packVector3         = (void *(*)(Vector3))getRealOffset(OFF_Zexis_PackVector3);
        realtimeSinceStartup= (float (*)())getRealOffset(OFF_Zexis_RealtimeSinceStartup);
        gameFacadeSend      = (bool  (*)(uint32_t, void *, uint8_t, bool))getRealOffset(OFF_Zexis_GameFacade_Send);
    }
}

// Throttle: số frame tối thiểu giữa 2 lần gửi 106 (1 = mỗi frame, 2 = mỗi 2 frame, 0/1 = max speed)
static int g_aimKillFrameThrottle = 1;
static int g_aimKillFrameCounter  = 0;

void StartAimkill() {
    if (!Vars.AimKillSend) return;

    // Throttle
    if (g_aimKillFrameThrottle > 1) {
        if (++g_aimKillFrameCounter < g_aimKillFrameThrottle) return;
        g_aimKillFrameCounter = 0;
    }

    void *match = game_sdk->Curent_Match();
    if (!match) return;

    void *local = game_sdk->GetLocalPlayer(match);
    if (!local || !game_sdk->Component_GetTransform(local)) return;
    if (game_sdk->get_IsDieing(local) || game_sdk->GetHp(local) <= 0) return;

    // ✅ 360° — mọi hướng, 400m
    void *enemy = GetClosestEnemy360();
    if (!enemy || enemy == local) return;
    if (!game_sdk->Component_GetTransform(enemy)) return;
    if (game_sdk->get_MaxHP && !game_sdk->get_MaxHP(enemy)) return;
    if (game_sdk->get_isLocalTeam && game_sdk->get_isLocalTeam(enemy)) return;
    if (game_sdk->get_IsDieing && game_sdk->get_IsDieing(enemy)) return;
    if (game_sdk->GetHp(enemy) <= 0) return;
    // ❌ BỎ: if (game_sdk->get_isVisible && !game_sdk->get_isVisible(enemy)) return;
    if (!tanghinh::isVisible(enemy)) return;

    AimKillCache::initOnce();

    auto getWeaponOnHand     = AimKillCache::getWeaponOnHand;
    auto getItemDataID       = AimKillCache::getItemDataID;
    auto getHeadCollider     = AimKillCache::getHeadCollider;
    auto getGameObject       = AimKillCache::getGameObject;
    auto getRange            = AimKillCache::getRange;
    auto getAimingEntity     = AimKillCache::getAimingEntity;
    auto buildCheckParams    = AimKillCache::buildCheckParams;
    auto weaponDoSomething   = AimKillCache::weaponDoSomething;
    auto startFiring         = AimKillCache::startFiring;
    auto stopFire            = AimKillCache::stopFire;
    auto currentSimTimer     = AimKillCache::currentSimTimer;
    auto createDamageReq     = AimKillCache::createDamageReq;
    auto getPlayerID         = AimKillCache::getPlayerID;
    auto playerIDToUint      = AimKillCache::playerIDToUint;
    auto packVector3         = AimKillCache::packVector3;
    auto realtimeSinceStartup= AimKillCache::realtimeSinceStartup;
    auto gameFacadeSend      = AimKillCache::gameFacadeSend;

    void *weapon = getWeaponOnHand(local);
    if (!weapon) return;

    // Reset cooldown về 0 → bắn nhanh nhất có thể
    *(float *)((uintptr_t)weapon + OFF_Zexis_Weapon_Field5F0) = 0.0f;

    int weaponId = getItemDataID(weapon);
    int baseDamage = *(int *)((uintptr_t)weapon + OFF_Zexis_Weapon_BaseDamageField);
    if (weaponId == -1 || baseDamage == 0) return;
    if (baseDamage < 100) baseDamage = 999;

    Vector3 localHead = GetHeadPosition(local);
    Vector3 enemyHead = GetHeadPosition(enemy);
    float range = getRange(weapon);
    if (Vector3::Distance(localHead, enemyHead) > range) return;

    void *objectPool = *(void **)((uint64_t)local + OFF_Zexis_Player_ObjectPool);
    if (!objectPool) return;

    COW_GamePlay_IHAAMHPPLMG_o localPlayerId =
        *(COW_GamePlay_IHAAMHPPLMG_o *)((uintptr_t)local + OFF_Zexis_Player_PlayerID);

    void *damageInfo = g_dmg99;
    if (!damageInfo) {
        void *playerAttributes = *(void **)((uint64_t)local + OFF_Zexis_Player_Attributes);
        if (playerAttributes) {
            void *damageModule = *(void **)((uint64_t)playerAttributes + OFF_Zexis_Player_DamageModule);
            if (damageModule)
                damageInfo = *(void **)((uint64_t)damageModule + OFF_Zexis_Player_DamageInfo);
        }
    }
    if (damageInfo) {
        *(int *)((char *)damageInfo + OFF_Zexis_DamageInfo_HitPart) = 1;
        *(void **)((char *)damageInfo + OFF_Zexis_DamageInfo_Weapon) = weapon;
        *(int *)((char *)damageInfo + OFF_Zexis_DamageInfo_DamageValue) = baseDamage;
        *(COW_GamePlay_IHAAMHPPLMG_o *)((char *)damageInfo + OFF_Zexis_DamageInfo_AttackerID) = localPlayerId;
    }

    void *headCollider = getHeadCollider(enemy);
    if (!headCollider) return;
    void *hitObject = getGameObject(headCollider);
    if (!hitObject) return;

    float dx = enemyHead.x - localHead.x;
    float dy = enemyHead.y - localHead.y;
    float dz = enemyHead.z - localHead.z;
    float dist = sqrtf(dx * dx + dy * dy + dz * dz);
    Vector3 direction;
    direction.x = 0.0f;
    direction.y = 0.0f;
    direction.z = 0.0f;
    if (dist > 0.0001f) {
        float inv = 1.0f / dist;
        direction.x = dx * inv;
        direction.y = dy * inv;
        direction.z = dz * inv;
    }

    void *aimTarget = *(void **)((uint64_t)enemy + OFF_Zexis_Player_AimTarget);
    if (aimTarget) {
        char *pool = (char *)objectPool;
        *(void **)(pool + OFF_Zexis_Pool_HitGameObject) = getGameObject(aimTarget);
        *(void **)(pool + OFF_Zexis_Pool_HitCollider) = aimTarget;
        *(Vector3 *)(pool + OFF_Zexis_Pool_HitLocation) = enemyHead;
        *(Vector3 *)(pool + OFF_Zexis_Pool_RayDir) = direction;
        *(Vector3 *)(pool + OFF_Zexis_Pool_RayDir2) = direction;
        *(Vector3 *)(pool + OFF_Zexis_Pool_StartPos) = localHead;
        *(int *)(pool + OFF_Zexis_Pool_Damage) = baseDamage;
        *(float *)(pool + OFF_Zexis_Pool_Distance) = dist;
        *(int *)(pool + OFF_Zexis_Pool_Flags60) = 1;
        *(int *)(pool + OFF_Zexis_Pool_Flags64) = 1;
        *(bool *)(pool + OFF_Zexis_Pool_Flag70) = true;
        *(bool *)(pool + OFF_Zexis_Pool_Flag71) = true;
    }

    startFiring(local, weapon);

    void *aimingEntity = getAimingEntity(local, objectPool);
    void *checkParams = buildCheckParams(weapon, enemy, headCollider, false, nullptr);
    if (!checkParams) {
        stopFire(local, weapon);
        return;
    }

    uint32_t enemyNetId = playerIDToUint(getPlayerID(enemy));
    weaponDoSomething(weapon, checkParams, enemyNetId);

    uint32_t localNetId = playerIDToUint(getPlayerID(local));
    uint32_t uniqueId = *(uint32_t *)((uintptr_t)weapon + OFF_Zexis_Weapon_UniqueNetID);
    uint32_t weaponField = (weaponId == 1) ? 0u : uniqueId;

    uint32_t simTick = 0;
    void *simTimer = currentSimTimer(nullptr);
    if (simTimer)
        simTick = *(uint32_t *)((char *)simTimer + OFF_Zexis_SimTimer_TickCount);

    message_C2S_RUDP_TakeDamage_Req_o2 *__ZexisDamagePacket =
        (message_C2S_RUDP_TakeDamage_Req_o2 *)createDamageReq(local);
    if (__ZexisDamagePacket) {
        __ZexisDamagePacket->AttackableEntityID = enemyNetId;
        __ZexisDamagePacket->RealDamageValue = 0;
        __ZexisDamagePacket->ShieldDamageValue = 0;
        __ZexisDamagePacket->DamageValue = (uint32_t)game_sdk->GetHp(enemy);
        __ZexisDamagePacket->DamagerID = localNetId;
        __ZexisDamagePacket->WeaponDataID = weaponId;
        __ZexisDamagePacket->WeaponUniqueID = weaponField;
        __ZexisDamagePacket->HitBodyPart = 1;
        __ZexisDamagePacket->TickCount = simTick;
        __ZexisDamagePacket->FirePos = (message_PVector3IntPos_o *)packVector3(localHead);
        __ZexisDamagePacket->TargetPos = (message_PVector3IntPos_o *)packVector3(enemyHead);
        __ZexisDamagePacket->CheckParams = checkParams;
        __ZexisDamagePacket->ArmorRatio = 1.f;
        __ZexisDamagePacket->ExtraFlag = 0;
        __ZexisDamagePacket->BaseTime = realtimeSinceStartup();
        gameFacadeSend(OFF_Zexis_TakeDamageMsgId, __ZexisDamagePacket, 2, 0);
    }

    stopFire(local, weapon);
    (void)aimingEntity;
    (void)hitObject;
}