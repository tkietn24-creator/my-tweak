#pragma once
#include <stdint.h>
#include "Helper/Mem.h"
#include "il2cpp/il2cpp_api.h"

struct message_EOBFCLNNIJH_o {
    void *klass;
    void *monitor;
    bool UDPClientMessageBase_m_GetFromPool;
    uint32_t PlayerID;
    uint32_t WeaponUniqueID;
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

// Cache
namespace Send108Cache {
    static void *klass = nullptr;
    static void *(*objectNew)(void *) = nullptr;
    static void (*ctor)(void *) = nullptr;
    static void *(*getWeaponOnHand)(void *) = nullptr;
    static int   (*getItemDataID)(void *) = nullptr;
    static COW_GamePlay_IHAAMHPPLMG_o (*getPlayerID)(void *) = nullptr;
    static uint32_t (*playerIDToUint)(COW_GamePlay_IHAAMHPPLMG_o) = nullptr;
    static bool  (*gameFacadeSend)(uint32_t, void *, uint8_t, bool) = nullptr;

    static inline void initOnce() {
        if (gameFacadeSend) return;
        klass            = FindGameClass("message", "EOBFCLNNIJH");
        objectNew        = (void *(*)(void *))UnitySym("il2cpp_object_new");
        ctor             = (void (*)(void *))getRealOffset(OFF_Zexis_Msg108_Ctor);
        getWeaponOnHand  = (void *(*)(void *))getRealOffset(OFF_Zexis_GetWeaponOnHand);
        getItemDataID    = (int   (*)(void *))getRealOffset(OFF_Zexis_GetItemDataID);
        getPlayerID      = (COW_GamePlay_IHAAMHPPLMG_o (*)(void *))getRealOffset(OFF_Zexis_GetPlayerID);
        playerIDToUint   = (uint32_t (*)(COW_GamePlay_IHAAMHPPLMG_o))getRealOffset(OFF_Zexis_PlayerIDToUint);
        gameFacadeSend   = (bool  (*)(uint32_t, void *, uint8_t, bool))getRealOffset(OFF_Zexis_GameFacade_Send);
    }
}

static void *NewReloadPacket() {
    Send108Cache::initOnce();
    if (!Send108Cache::klass || !Send108Cache::objectNew) return nullptr;
    void *obj = Send108Cache::objectNew(Send108Cache::klass);
    if (!obj) return nullptr;
    if (Send108Cache::ctor) Send108Cache::ctor(obj);
    return obj;
}

static bool Send108(void *local, void *enemy) {
    if (!Vars.AimKillSend || !local || !enemy) return false;
    // ❌ BỎ: get_isVisible (view-based, chặn địch sau lưng)
    if (!tanghinh::isVisible(enemy)) return false;   // giữ raycast

    Send108Cache::initOnce();

    auto getWeaponOnHand = Send108Cache::getWeaponOnHand;
    auto getItemDataID   = Send108Cache::getItemDataID;
    auto getPlayerID     = Send108Cache::getPlayerID;
    auto playerIDToUint  = Send108Cache::playerIDToUint;
    auto gameFacadeSend  = Send108Cache::gameFacadeSend;

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