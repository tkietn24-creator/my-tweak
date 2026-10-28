// Copyright (c) 2026 zexisyy. All rights reserved.
#pragma once
#include <stdint.h>
#include "il2cpp/il2cpp_api.h"
#include "Helper/Mem.h"

#ifndef ZEXIS_COW_GAMEPLAY_DEFINED
#define ZEXIS_COW_GAMEPLAY_DEFINED
struct COW_GamePlay_IHAAMHPPLMG_o {
    uint32_t m_Value;
    uint32_t m_ID;
    uint8_t  m_TeamID;
    uint8_t  m_ShortID;
    uint64_t m_IDMask;
};
#endif

struct message_EOBFCLNNIJH_o {
    void *klass;
    void *monitor;
    bool UDPClientMessageBase_m_GetFromPool;
    uint32_t PlayerID;          /* +0x14 */
    uint32_t WeaponUniqueID;    /* +0x18 */
};

#define OFF_Zexis_ReloadMsgId                     108
#define OFF_Zexis_GameFacade_Send                 0x5926D78
#define OFF_Zexis_Msg108_Ctor                     0x277189C
#define OFF_Zexis_Msg108_Id                       0x14
#define OFF_Zexis_Msg108_Unique                   0x18
#define OFF_Zexis_GetWeaponOnHand                 0x5616118
#define OFF_Zexis_GetItemDataID                   0x5B0B8EC
#define OFF_Zexis_Weapon_UniqueNetID              0x10
#define OFF_Zexis_GetPlayerID                     0x55FE154
#define OFF_Zexis_PlayerIDToUint                  0x649046C

typedef bool (*GameFacade_Send_t)(uint32_t messageID, void *msg, uint8_t sendOption, bool cacheMsgAnyWay);
typedef void (*Msg108_Ctor_t)(void *self);
typedef void *(*GetWeaponOnHand_t)(void *player);
typedef int (*GetItemDataID_t)(void *weapon);
typedef COW_GamePlay_IHAAMHPPLMG_o (*GetPlayerID_t)(void *player);
typedef uint32_t (*PlayerIDToUint_t)(COW_GamePlay_IHAAMHPPLMG_o id);

static void *NewReloadPacket() {
    static void *klass = nullptr;
    if (!klass) klass = FindGameClass("message", "EOBFCLNNIJH");
    auto objectNew = (il2cpp_object_new_t)UnitySym("il2cpp_object_new");
    if (!klass || !objectNew) return nullptr;
    void *obj = objectNew(klass);
    if (!obj) return nullptr;
    ((Msg108_Ctor_t)getRealOffset(OFF_Zexis_Msg108_Ctor))(obj);
    return obj;
}

static bool Send108(void *local, void *enemy) {
    if (!Vars.AimKillSend || !local || !enemy) return false;
    if (!game_sdk->get_isVisible(enemy) || !tanghinh::isVisible(enemy)) return false;

    auto getWeaponOnHand = (void *(*)(void *))getRealOffset(OFF_Zexis_GetWeaponOnHand);
    auto getItemDataID = (int (*)(void *))getRealOffset(OFF_Zexis_GetItemDataID);
    auto getPlayerID = (COW_GamePlay_IHAAMHPPLMG_o (*)(void *))getRealOffset(OFF_Zexis_GetPlayerID);
    auto playerIDToUint = (uint32_t (*)(COW_GamePlay_IHAAMHPPLMG_o))getRealOffset(OFF_Zexis_PlayerIDToUint);
    auto gameFacadeSend = (bool (*)(uint32_t, void *, uint8_t, bool))getRealOffset(OFF_Zexis_GameFacade_Send);

    void *weapon = getWeaponOnHand(local);
    if (!weapon) return false;

    int weaponId = getItemDataID(weapon);
    uint32_t uniqueId = *(uint32_t *)((uintptr_t)weapon + OFF_Zexis_Weapon_UniqueNetID);
    uint32_t weaponField = (weaponId == 1) ? 0u : uniqueId;
    uint32_t localId = playerIDToUint(getPlayerID(local));

    void *packet = NewReloadPacket();
    if (!packet) return false;

    *(uint32_t *)((char *)packet + OFF_Zexis_Msg108_Id) = localId;
    *(uint32_t *)((char *)packet + OFF_Zexis_Msg108_Unique) = weaponField;
    return gameFacadeSend(OFF_Zexis_ReloadMsgId, packet, 2, 0);
}