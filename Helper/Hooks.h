#import "vinhtran.hpp"
#import "loading.hxx"
#include <fstream>
#define FMT_HEADER_ONLY
#include "fmt/core.h"
#include "Other/dobby_defines.h"
#import "Other/H5hook.h"
#include <mach/mach_time.h>
#include <map>
#include <unordered_map>
#include <atomic>
#include <thread>
#include <chrono>
#include <mutex>
#include <unistd.h>
#import "hook/hook.h"
#import "JRMemory.framework/Headers/MemScan.h"

struct PtrHash { size_t operator()(void* p) const { return (size_t)p >> 3; } };

static long lastCheckTime = 0;
static std::unordered_map<void*, float, PtrHash> enemyOriginalY;

static bool  g_underCameraAdjusted = false;
static float g_underLocalOriginalY = 0.0f;

struct EnemyCacheData { Vector3 bestRevealPos; bool hasBestPos; Vector3 lastPos; bool hasPos; };
static std::unordered_map<void*, EnemyCacheData, PtrHash> enemyCache;

struct VisCacheEntry { bool visible; double lastCheck; };
static std::unordered_map<void*, VisCacheEntry, PtrHash> g_visCache;
static const double kVisCacheInterval = 0.15;

static inline double NowSeconds() {
    static mach_timebase_info_data_t tb = {0,0};
    if (tb.denom == 0) mach_timebase_info(&tb);
    return (double)mach_absolute_time() * tb.numer / tb.denom * 1e-9;
}

struct NameSizeCache { std::string lastName; ImVec2 size; };
static std::unordered_map<void*, NameSizeCache, PtrHash> g_nameSizeCache;

static std::unordered_map<void*, double, PtrHash> g_telePulled;
static const double kTelePullReset = 0.35;

struct AirSnapEntry { Vector3 pos; double t; };
static std::unordered_map<void*, AirSnapEntry, PtrHash> g_airSnappedPos;
static const double kAirSnapTTL = 0.30;

struct AirZigzagState {
    Vector3 basePos;
    float   side;
    double  lastSwitch;
    bool    hasBase;
};
static std::unordered_map<void*, AirZigzagState, PtrHash> g_airZigzag;

static std::unordered_map<void*, float> baseGroundYMap;
static void*  lastBaseMatch   = nullptr;
static double lastBaseCleanup = 0.0;

static std::atomic<uint64_t> g_autoFireTarget{0};
static std::atomic<double>   g_lastAutoFireShot{0.0};

int g_espLang = 0;

struct HitObjectInfo {
    void *klass; void *monitor; bool m_IsInPool;
    void *HitObject; void *HitCollider;
    Vector3 HitLocation; Vector3 RayDir; Vector3 StartPosition;
    int32_t Damage; float Distance; int32_t ActorLayer; int32_t HitGroup;
    void *HitPhysicMaterial; bool IgnoreHappens; bool ViewBlocked;
    struct Vector3 OrigStartPosition;
    uint8_t SpecialHitType; uint32_t SpecialHitLevelObjID;
};

bool doublegun = false;

bool resetguest = false;

bool resetguesthook(void* _this) {
    (void)_this;
    static int c = 0;
    if (++c <= 5 || c % 200 == 0)
        printf("[ResetGuest] call #%d, state=%d\n", c, resetguest);
    return resetguest;
}

class game_sdk_t;
extern game_sdk_t *game_sdk;
Vector3 GetHitboxPosition(void* player, int hitbox);


#define FAKE_NAME_TEXT       " TunAnh06"
#define FAKE_NAME_OFFSET     0x490
#define FAKE_NAME_COLOR      "00BFFF"

static void*    g_fakeNamePawn   = nullptr;
static uint64_t g_fakeNamePtr    = 0;
static bool     g_fakeNameInit   = false;

static void FakeName_Update(void* myPawnObject) {
    if (!myPawnObject) return;

    void* oldStr = *(void**)((uint64_t)myPawnObject + FAKE_NAME_OFFSET);
    if (!oldStr) return;

    if (!g_fakeNameInit || g_fakeNamePawn != myPawnObject || g_fakeNamePtr == 0) {
        uint64_t klass = *(uint64_t*)oldStr;
        if (!klass) return;

        NSString* base = [NSString stringWithUTF8String:FAKE_NAME_TEXT];
        NSMutableString* colored = [NSMutableString string];
        for (NSUInteger i = 0; i < base.length; i++) {
            unichar c = [base characterAtIndex:i];
            if (c == ' ') [colored appendString:@" "];
            else [colored appendFormat:@"[%s]%C", FAKE_NAME_COLOR, c];
        }
        NSUInteger len = colored.length;
        size_t size = 0x14 + (len * 2) + 2;
        void* newAlloc = malloc(size);
        if (!newAlloc) return;
        memset(newAlloc, 0, size);

        *(uint64_t*)((uint64_t)newAlloc + 0x00) = klass;
        *(uint64_t*)((uint64_t)newAlloc + 0x08) = 0;
        *(int32_t* )((uint64_t)newAlloc + 0x10) = (int32_t)len;
        for (NSUInteger i = 0; i < len; i++) {
            unichar c = [colored characterAtIndex:i];
            *(uint16_t*)((uint64_t)newAlloc + 0x14 + (i * 2)) = (uint16_t)c;
        }
        *(uint16_t*)((uint64_t)newAlloc + 0x14 + (len * 2)) = 0;

        g_fakeNamePtr   = (uint64_t)newAlloc;
        g_fakeNamePawn  = myPawnObject;
        g_fakeNameInit  = true;
    }

    if (g_fakeNamePtr) {
        *(uint64_t*)((uint64_t)myPawnObject + FAKE_NAME_OFFSET) = g_fakeNamePtr;
    }
}

struct Vars_t
{
    bool fastfire = false;
    bool SpinBotEnabled = false;
    float SpinBotSpeed = 0.1f;
    float currentY = 0.0f;
    bool noreload = false;
    bool vohandan = false;
    bool AIRPlayer = false;
    bool telekill = false;
    bool Nangdich = false;

    bool SilentAim = false;
    float SilentFov = 150.0f;

    bool AutoFire = false;
    float AutoFireDelay = 0.02f;
    bool Enable = {};
    bool AimbotEnable = {};
    bool Aimbot = {};
    bool ShowFovCircle = true;
    bool camxa = false;
    float CamXaValue = 10.0f;

    float AimFov = 150.0f;
    int AimCheck = {};
    bool ESPCount = {};
    int AimType = {};
    int AimWhen = 3;
    int AimMode = 2;
    bool isAimFov = {};
    int AimHitbox = 0;
    const char* aimHitboxes[3] = {"Head", "Neck", "Body"};
    const char *dir[4] = {"None", "Fire", "Scope", "Bắn và Ngắm"};
    const char *aimModes[3] = {"Aim 360°", "Aim 180°", "AimFov"};
    bool AimRandomEnable = false;
    int  AimRandomMode = 2;
    const char *aimRandomModes[3] = {"25%", "50%", "100%"};
    bool VisibleCheck = true;
    bool lines = {};
    bool Box = {};
    bool Outline = {};
    bool Name = {};
    bool Health = {};
    bool Distance = {};
    bool fovaimglow = {};
    bool circlepos = {};
    bool skeleton = {};
    bool OOF = {};
    bool enemycount = {};

    float espDrawDistance = 250.0f;

    float fovLineColor[4]      = {1.0f, 1.0f, 1.0f, 1.0f};
    ImVec4 boxColor            = ImVec4(1.0f, 1.0f, 1.0f, 1.0f);
    float espLineColor[4]      = {1.0f, 1.0f, 1.0f, 1.0f};
    float espBoxColor[4]       = {0.0f, 1.0f, 1.0f, 1.0f};
    float espSkeletonColor[4]  = {0.0f, 1.0f, 0.0f, 1.0f};
    float AimSpeed = 50.0f;
    bool IgnoreKnocked = true;

    bool AimKillSend = false;

    bool Underground = false;
    bool ShowUndergroundButton = false;
} Vars;


bool DOUBLE(void* _this) {
    if (doublegun) {
        return true;
    } else {
        return false;
    }
}

bool InSwapWeaponCD(void* _this) {
    (void)_this;
    return false;
}

class game_sdk_t
{
public:
    void init();
    int (*GetHp)(void *player);
    void *(*Curent_Match)();
    void *(*GetLocalPlayer)(void *Game);
    void *(*GetHeadPositions)(void *player);
    Vector3 (*get_position)(void *player);
    void *(*Component_GetTransform)(void *player);
    void *(*get_camera)();
    Vector3 (*WorldToViewpoint)(void*, Vector3, int);
    bool (*get_isVisible)(void *player);
    bool (*get_isLocalTeam)(void *player);
    bool (*get_IsDieing)(void *player);
    int (*get_MaxHP)(void *player);
    Vector3 (*GetForward)(void *player);
    void (*set_aim)(void *, Quaternion look);
    bool (*get_IsSighting)(void *player);
    bool (*get_IsFiring)(void *player);
    monoString *(*name)(void *player);
    void *(*_GetHeadPositions)(void *);
    void *(*_newHipMods)(void *);
    void *(*_GetLeftAnkleTF)(void *);
    void *(*_GetRightAnkleTF)(void *);
    void *(*_GetLeftToeTF)(void *);
    void *(*_GetRightToeTF)(void *);
    void *(*_getLeftHandTF)(void *);
    void *(*_getRightHandTF)(void *);
    void *(*_getLeftForeArmTF)(void *);
    void *(*_getRightForeArmTF)(void *);
};

game_sdk_t *game_sdk = new game_sdk_t();

void game_sdk_t::init()
{
    this->GetHp = (int (*)(void *))getRealOffset(oxo("0x56AA7C8"));
    this->Curent_Match = (void *(*)())getRealOffset(oxo("0x591B898"));
    this->GetLocalPlayer = (void *(*)(void *))getRealOffset(oxo("0x320FF7C"));
    this->GetHeadPositions = (void *(*)(void *))getRealOffset(oxo("0x56CA948"));
    this->get_position = (Vector3(*)(void *))getRealOffset(oxo("0x8D6C1EC"));
    this->Component_GetTransform = (void *(*)(void *))getRealOffset(oxo("0x8D59C2C"));
    this->get_camera = (void *(*)())getRealOffset(oxo("0x8CFF0B4"));
    this->WorldToViewpoint = (Vector3(*)(void*, Vector3, int))getRealOffset(oxo("0x8CFEA34"));
    this->get_isVisible = (bool (*)(void *))getRealOffset(oxo("0x563B10C"));
    this->get_isLocalTeam = (bool (*)(void *))getRealOffset(oxo("0x5655F1C"));
    this->get_IsDieing = (bool (*)(void *))getRealOffset(oxo("0x561C768"));
    this->get_MaxHP = (int (*)(void *))getRealOffset(oxo("0x5613110"));
    this->GetForward = (Vector3(*)(void *))getRealOffset(oxo("0x8D6CBE4"));
    this->set_aim = (void (*)(void *, Quaternion))getRealOffset(oxo("0x5636F80"));
    this->get_IsSighting = (bool (*)(void *))getRealOffset(oxo("0x5629C84"));
    this->get_IsFiring = (bool (*)(void *))getRealOffset(oxo("0x56200F0"));
    this->name = (monoString * (*)(void *player)) getRealOffset(oxo("0x5630F10"));

    this->_GetHeadPositions = (void *(*)(void *))getRealOffset(oxo("0x56CA948"));
    this->_newHipMods = (void *(*)(void *))getRealOffset(oxo("0x56CAAF8"));
    this->_GetLeftAnkleTF = (void *(*)(void *))getRealOffset(oxo("0x56CAF48"));
    this->_GetRightAnkleTF = (void *(*)(void *))getRealOffset(oxo("0x56CB054"));
    this->_GetLeftToeTF = (void *(*)(void *))getRealOffset(oxo("0x56CB160"));
    this->_GetRightToeTF = (void *(*)(void *))getRealOffset(oxo("0x56CB280"));
    this->_getLeftHandTF = (void *(*)(void *))getRealOffset(oxo("0x5635F18"));
    this->_getRightHandTF = (void *(*)(void *))getRealOffset(oxo("0x563601C"));
    this->_getLeftForeArmTF = (void *(*)(void *))getRealOffset(oxo("0x5636120"));
    this->_getRightForeArmTF = (void *(*)(void *))getRealOffset(oxo("0x5636224"));
}

bool IsGod(void *player){
    if (!player) return false;
    return *(bool *)((uint64_t) player + 0x1024);
}

void *get_gameObject(void *Pthis)
{
    if (!Pthis) return nullptr;
    return ((void* (*)(void *))getRealOffset(0x8D59C7C))(Pthis);
}

static void *GetWeaponOnHand1(void *local) {
    if (!local) return nullptr;
    void *(*_GetWeaponOnHand1)(void *local) = (void *(*)(void *))getRealOffset(0x5616118);
    return _GetWeaponOnHand1(local);
}

static void Transform_INTERNAL_SetRotation(void *transform, Quaternion rot) {
    if (!transform) return;
    void (*_Transform_INTERNAL_SetRotation)(void *, Quaternion) = (void (*)(void *, Quaternion))getRealOffset(0x8D6C68C);
    _Transform_INTERNAL_SetRotation(transform, rot);
}

static Vector3 Transform_INTERNAL_GetPosition(void *transform) {
    if (!transform) return Vector3::zero();
    Vector3 out = Vector3::zero();
    void (*_Transform_INTERNAL_GetPosition)(void *transform, Vector3 * out) = (void (*)(void *, Vector3 *))getRealOffset(ENCRYPTOFFSET("0x8D6C250"));
    _Transform_INTERNAL_GetPosition(transform, &out);
    return out;
}

static void Transform_INTERNAL_SetPosition(void *player, Vvector3 inn) {
    if (!player) return;
    void (*_Transform_INTERNAL_SetPosition)(void *transform, Vvector3 in) = (void (*)(void *, Vvector3))getRealOffset(oxo("0x8D6C328"));
    _Transform_INTERNAL_SetPosition(player, inn);
}

static float GetHorizontalJoystick() { return ((float (*)(void))getRealOffset(0x940FC2C))(); }
static float GetVerticalJoystick()   { return ((float (*)(void))getRealOffset(0x940FC4C))(); }
static bool IsJoystickMoving() {
    float h = GetHorizontalJoystick();
    float v = GetVerticalJoystick();
    return (h != 0.0f || v != 0.0f);
}

namespace Camera$$WorldToScreen
{
ImVec2 Regular(Vector3 pos) {
    auto cam = game_sdk->get_camera();
    if (!cam) return {0,0};
    Vector3 worldPoint = game_sdk->WorldToViewpoint(cam,pos, 2);
    Vector3 location;
    int ScreenWidth = ImGui::GetIO().DisplaySize.x;
    int ScreenHeight = ImGui::GetIO().DisplaySize.y;
    location.x = ScreenWidth * worldPoint.x;
    location.y = ScreenHeight - worldPoint.y * ScreenHeight;
    location.z  = worldPoint.z;
    return {location.x, location.y};
}

ImVec2 Checker(Vector3 pos, bool &checker) {
    auto cam = game_sdk->get_camera();
    if (!cam) return {0, 0};
    Vector3 worldPoint = game_sdk->WorldToViewpoint(cam,pos, 4);
    Vector3 location;
    int ScreenWidth = ImGui::GetIO().DisplaySize.x;
    int ScreenHeight = ImGui::GetIO().DisplaySize.y;
    location.x = ScreenWidth * worldPoint.x;
    location.y = ScreenHeight - worldPoint.y * ScreenHeight;
    location.z = worldPoint.z;
    checker = location.z > 1;
    return {location.x, location.y};
}
}

Vector3 GetBonePosition(void *player, void *(*transformGetter)(void *)) {
    if (!player || !transformGetter) return Vector3();
    void *transform = transformGetter(player);
    return transform ? game_sdk->get_position(game_sdk->Component_GetTransform(transform)) : Vector3();
}

Vector3 GetHitboxPosition(void* player, int hitbox) {
    if (!player) return Vector3::zero();
    switch (hitbox) {
        case 0: return GetBonePosition(player, game_sdk->GetHeadPositions);
        case 1: {
            Vector3 headPos = GetBonePosition(player, game_sdk->GetHeadPositions);
            return headPos == Vector3::zero() ? headPos : Vector3(headPos.x, headPos.y - 0.2f, headPos.z);
        }
        case 2: {
            Vector3 headPos = GetBonePosition(player, game_sdk->GetHeadPositions);
            return headPos == Vector3::zero() ? headPos : Vector3(headPos.x, headPos.y - 0.4f, headPos.z);
        }
        default: return GetBonePosition(player, game_sdk->GetHeadPositions);
    }
}

#define OFF_HIT_OBJ       0xE50
#define OFF_HIT_AMMO_BASE 0x4C
#define OFF_HIT_DIR       0x40
#define OFF_HIT_TARGET    0x28

static std::atomic<uint64_t> g_SilentMyPawn{0};
static std::atomic<uint64_t> g_SilentTargetPawn{0};
static std::atomic<int>      g_SilentPosMode{0};
static std::atomic<bool>     g_SilentEnabled{false};
static std::atomic<float>    g_TgtX{0.f}, g_TgtY{0.f}, g_TgtZ{0.f};
static std::atomic<bool>     g_TgtValid{false};
static std::mutex            g_SilentLock;
static uint64_t              g_HitObjInfo = 0;
static Vector3               g_SilentTargetPos = {0, 0, 0};
static bool                  g_HasData = false;

static inline bool VecFiniteI(const Vector3 &v) {
    return isfinite(v.x) && isfinite(v.y) && isfinite(v.z);
}
static inline bool IsZeroVecI(const Vector3 &v) {
    return v.x == 0.0f && v.y == 0.0f && v.z == 0.0f;
}
static inline uint64_t NowUsI() {
    return (uint64_t)std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

static void SilentWriteOnceInternal(uint64_t hitObj, const Vector3 &targetPos) {
    if (!hitObj) return;
    Vector3 ammoBase = *(Vector3*)(hitObj + OFF_HIT_AMMO_BASE);
    if (!VecFiniteI(ammoBase)) return;

    Vector3 dir;
    dir.x = targetPos.x - ammoBase.x;
    dir.y = targetPos.y - ammoBase.y;
    dir.z = targetPos.z - ammoBase.z;
    if (!VecFiniteI(dir)) return;

    float len = sqrtf(dir.x*dir.x + dir.y*dir.y + dir.z*dir.z);
    if (len < 0.0001f) return;

    Vector3 oldDir = *(Vector3*)(hitObj + OFF_HIT_DIR);
    float oldLen = VecFiniteI(oldDir) ? sqrtf(oldDir.x*oldDir.x + oldDir.y*oldDir.y + oldDir.z*oldDir.z) : 0;

    Vector3 outDir;
    if (oldLen > 0.001f) {
        float k = oldLen / len;
        outDir.x = dir.x * k;
        outDir.y = dir.y * k;
        outDir.z = dir.z * k;
    } else {
        outDir = dir;
    }

    *(Vector3*)(hitObj + OFF_HIT_DIR) = outDir;
    *(Vector3*)(hitObj + OFF_HIT_TARGET) = targetPos;
}

static void SilentTargetTrackVoidInternal() {
    while (true) {
        if (!g_SilentEnabled.load()) {
            g_TgtValid.store(false);
            std::this_thread::sleep_for(std::chrono::milliseconds(4));
            continue;
        }
        uint64_t tgt = g_SilentTargetPawn.load();
        bool ok = false;
        Vector3 pos = {0, 0, 0};

        if (tgt && game_sdk && game_sdk->Component_GetTransform((void*)tgt)) {
            Vector3 live = GetHitboxPosition((void*)tgt, g_SilentPosMode.load());
            if (!IsZeroVecI(live) && VecFiniteI(live)) { pos = live; ok = true; }
        }
        if (!ok) {
            g_SilentLock.lock();
            if (g_HasData) { pos = g_SilentTargetPos; ok = true; }
            g_SilentLock.unlock();
        }
        if (ok) {
            g_TgtX.store(pos.x, std::memory_order_relaxed);
            g_TgtY.store(pos.y, std::memory_order_relaxed);
            g_TgtZ.store(pos.z, std::memory_order_relaxed);
            g_TgtValid.store(true, std::memory_order_release);
        } else {
            g_TgtValid.store(false, std::memory_order_release);
        }
        std::this_thread::sleep_for(std::chrono::microseconds(800));
    }
}

static inline bool SilentGetTargetPosInternal(Vector3 &out) {
    if (!g_TgtValid.load(std::memory_order_acquire)) return false;
    out.x = g_TgtX.load(std::memory_order_relaxed);
    out.y = g_TgtY.load(std::memory_order_relaxed);
    out.z = g_TgtZ.load(std::memory_order_relaxed);
    return VecFiniteI(out);
}

static void AimSilentVoidInternal() {
    uint64_t lastHitObj = 0;
    Vector3  lastBase = {0, 0, 0};
    uint64_t lastSeenUs = 0;

    while (true) {
        if (!g_SilentEnabled.load(std::memory_order_relaxed)) {
            lastHitObj = 0;
            lastBase = Vector3(0, 0, 0);
            lastSeenUs = 0;
            std::this_thread::sleep_for(std::chrono::milliseconds(4));
            continue;
        }

        uint64_t myPawn = g_SilentMyPawn.load(std::memory_order_relaxed);
        if (!myPawn) {
            std::this_thread::sleep_for(std::chrono::microseconds(200));
            continue;
        }

        Vector3 targetPos;
        bool haveTarget = SilentGetTargetPosInternal(targetPos);

        uint64_t liveObj = *(uint64_t*)(myPawn + OFF_HIT_OBJ);
        uint64_t nowUs = 0;
        uint64_t hitObj = 0;

        if (liveObj) {
            if (haveTarget) SilentWriteOnceInternal(liveObj, targetPos);
            hitObj = liveObj;
            g_HitObjInfo = liveObj;
            lastSeenUs = NowUsI();
        } else {
            nowUs = NowUsI();
            if (g_HitObjInfo && lastSeenUs && (nowUs - lastSeenUs) < 25000) {
                hitObj = g_HitObjInfo;
            } else {
                lastHitObj = 0;
                lastBase = Vector3(0, 0, 0);
                continue;
            }
        }

        if (!haveTarget) continue;

        Vector3 base = *(Vector3*)(hitObj + OFF_HIT_AMMO_BASE);
        bool baseChanged = VecFiniteI(base) &&
            (fabsf(base.x - lastBase.x) > 0.0005f ||
             fabsf(base.y - lastBase.y) > 0.0005f ||
             fabsf(base.z - lastBase.z) > 0.0005f);

        if (hitObj != lastHitObj || baseChanged) {
            lastHitObj = hitObj;
            lastBase = base;
            uint64_t burstStart = NowUsI();
            int i = 0;
            while (NowUsI() - burstStart < 4000) {
                SilentWriteOnceInternal(hitObj, targetPos);
                if ((++i & 15) == 0) {
                    Vector3 t;
                    if (SilentGetTargetPosInternal(t)) targetPos = t;
                    uint64_t chk = *(uint64_t*)(myPawn + OFF_HIT_OBJ);
                    if (chk && chk != hitObj) break;
                }
            }
            continue;
        }

        SilentWriteOnceInternal(hitObj, targetPos);
    }
}

static void ClearSilentStateInternal() {
    g_SilentEnabled.store(false);
    g_SilentMyPawn.store(0);
    g_SilentTargetPawn.store(0);
    g_SilentLock.lock();
    g_HasData = false;
    g_HitObjInfo = 0;
    g_SilentLock.unlock();
}

static void SilentAimActivate(void* localPlayer, void* targetEnemy, int hitbox) {
    if (!localPlayer || !targetEnemy) { ClearSilentStateInternal(); return; }
    Vector3 targetPos = GetHitboxPosition(targetEnemy, hitbox);
    if (IsZeroVecI(targetPos)) return;

    uint64_t hitObj = *(uint64_t*)((uint64_t)localPlayer + OFF_HIT_OBJ);
    g_SilentLock.lock();
    if (hitObj) g_HitObjInfo = hitObj;
    g_SilentTargetPos = targetPos;
    g_HasData = true;
    g_SilentLock.unlock();

    g_SilentTargetPawn.store((uint64_t)targetEnemy);
    g_SilentPosMode.store(hitbox);
    g_SilentMyPawn.store((uint64_t)localPlayer);
    g_SilentEnabled.store(true);
    if (hitObj) SilentWriteOnceInternal(hitObj, targetPos);
}

Vector3 getPosition(void *player) {
    if (!player) return Vector3::zero();
    void *tf = game_sdk->Component_GetTransform(player);
    return tf ? game_sdk->get_position(tf) : Vector3::zero();
}

Vector3 GetHeadPosition(void *player) {
    if (!player) return Vector3::zero();
    void *headTF = game_sdk->GetHeadPositions(player);
    return headTF ? game_sdk->get_position(headTF) : Vector3::zero();
}

static Vector3 CameraMain(void *player) {
    if (!player) return Vector3::zero();
    void *camPtr = *(void **)((uint64_t)player + oxo("0x3E8"));
    return camPtr ? game_sdk->get_position(camPtr) : Vector3::zero();
}

Quaternion GetRotationToTheLocation(Vector3 Target, float Height, Vector3 MyEnemy) {
    Vector3 direction = (Target + Vector3(0, Height, 0)) - MyEnemy;
    return Quaternion::LookRotation(direction, Vector3(0, 1, 0));
}

Quaternion GetCurrentRotation(void* player) {
    if (!player) return Quaternion();
    void* transform = game_sdk->Component_GetTransform(player);
    if (!transform) return Quaternion();
    return Quaternion::LookRotation(game_sdk->GetForward(transform), Vector3(0, 1, 0));
}

#include "Helper/Ext.h"

class tanghinh {
public:
    static Vector3 Transform_GetPosition(void *player) {
        if (!player) return Vector3::zero();
        Vector3 out = Vector3::zero();
        void (*_Transform_GetPosition)(void *transform, Vector3 *out) = (void (*)(void *, Vector3 *))getRealOffset(oxo("0x8D6C250"));
        _Transform_GetPosition(player, &out);
        return out;
    }

    static void *Player_GetHeadCollider(void *player) {
        if (!player) return nullptr;
        void *(*_Player_GetHeadCollider)(void *players) = (void *(*)(void *))getRealOffset(oxo("0x5634F3C"));
        return _Player_GetHeadCollider(player);
    }

    static bool Physics_Raycast(Vector3 camLocation, Vector3 headLocation, unsigned int LayerID, void *collider) {
        bool (*_Physics_Raycast)(Vector3 camLocation, Vector3 headLocation, unsigned int LayerID, void *collider) = (bool (*)(Vector3, Vector3, unsigned int, void *))getRealOffset(oxo("0x6396DE4"));
        return _Physics_Raycast(camLocation, headLocation, LayerID, collider);
    }

    static bool isVisible(void *enemy) {
        if (enemy != NULL) {
            void *hitObj = NULL;
            void *cam = game_sdk->get_camera();
            if (!cam) return false;
            void *camTF = game_sdk->Component_GetTransform(cam);
            void *headCollider = Player_GetHeadCollider(enemy);
            if (!camTF || !headCollider) return false;
            auto Camera = Transform_GetPosition(camTF);
            auto Target = Transform_GetPosition(game_sdk->Component_GetTransform(headCollider));
            return !Physics_Raycast(Camera, Target, 12, &hitObj);
        }
        return false;
    }
};

static bool isVisibleCached(void *enemy) {
    if (!enemy) return false;
    double now = NowSeconds();
    auto it = g_visCache.find(enemy);
    if (it != g_visCache.end() && (now - it->second.lastCheck) < kVisCacheInterval)
        return it->second.visible;
    bool vis = tanghinh::isVisible(enemy);
    g_visCache[enemy] = {vis, now};
    return vis;
}

static void CleanupVisCache() {
    double now = NowSeconds();
    for (auto it = g_visCache.begin(); it != g_visCache.end(); ) {
        if (now - it->second.lastCheck > 2.0) it = g_visCache.erase(it); else ++it;
    }
    if (g_nameSizeCache.size() > 256) g_nameSizeCache.clear();
    for (auto it = g_airSnappedPos.begin(); it != g_airSnappedPos.end(); ) {
        if (now - it->second.t > 1.0) it = g_airSnappedPos.erase(it); else ++it;
    }
    for (auto it = g_telePulled.begin(); it != g_telePulled.end(); ) {
        if (now - it->second > 2.0) it = g_telePulled.erase(it); else ++it;
    }
}
void DrawSkeleton(void *player, ImDrawList *drawList)
{
    if (!player || !drawList) return;
    bool isPlayerVisible = tanghinh::isVisible(player);
    Vector3 headPos = GetBonePosition(player, game_sdk->_GetHeadPositions);
    Vector3 hipPos = GetBonePosition(player, game_sdk->_newHipMods);
    Vector3 leftAnklePos = GetBonePosition(player, game_sdk->_GetLeftAnkleTF);
    Vector3 rightAnklePos = GetBonePosition(player, game_sdk->_GetRightAnkleTF);
    Vector3 leftToePos = GetBonePosition(player, game_sdk->_GetLeftToeTF);
    Vector3 rightToePos = GetBonePosition(player, game_sdk->_GetRightToeTF);
    Vector3 leftHandPos = GetBonePosition(player, game_sdk->_getLeftHandTF);
    Vector3 rightHandPos = GetBonePosition(player, game_sdk->_getRightHandTF);
    Vector3 leftForeArmPos = GetBonePosition(player, game_sdk->_getLeftForeArmTF);
    Vector3 rightForeArmPos = GetBonePosition(player, game_sdk->_getRightForeArmTF);

    bool visible;
    ImVec2 headScreen = Camera$$WorldToScreen::Checker(headPos, visible);
    if (!visible) return;

    ImVec2 hipScreen = Camera$$WorldToScreen::Regular(hipPos);
    ImVec2 leftAnkleScreen = Camera$$WorldToScreen::Regular(leftAnklePos);
    ImVec2 rightAnkleScreen = Camera$$WorldToScreen::Regular(rightAnklePos);
    ImVec2 leftToeScreen = Camera$$WorldToScreen::Regular(leftToePos);
    ImVec2 rightToeScreen = Camera$$WorldToScreen::Regular(rightToePos);
    ImVec2 leftHandScreen = Camera$$WorldToScreen::Regular(leftHandPos);
    ImVec2 rightHandScreen = Camera$$WorldToScreen::Regular(rightHandPos);
    ImVec2 leftForeArmScreen = Camera$$WorldToScreen::Regular(leftForeArmPos);
    ImVec2 rightForeArmScreen = Camera$$WorldToScreen::Regular(rightForeArmPos);
    ImColor boneColor = isPlayerVisible ? ImColor(0, 255, 0) : ImColor(255, 255, 255);
    float thickness = 1.0f;

    drawList->AddCircle(headScreen, 2.0f, boneColor, 12, thickness);
    drawList->AddLine(headScreen, hipScreen, boneColor, thickness);
    drawList->AddLine(headScreen, leftForeArmScreen, boneColor, thickness);
    drawList->AddLine(headScreen, rightForeArmScreen, boneColor, thickness);
    drawList->AddLine(leftForeArmScreen, leftHandScreen, boneColor, thickness);
    drawList->AddLine(rightForeArmScreen, rightHandScreen, boneColor, thickness);
    drawList->AddLine(hipScreen, leftAnkleScreen, boneColor, thickness);
    drawList->AddLine(hipScreen, rightAnkleScreen, boneColor, thickness);
    drawList->AddLine(leftAnkleScreen, leftToeScreen, boneColor, thickness);
    drawList->AddLine(rightAnkleScreen, rightToeScreen, boneColor, thickness);
}

bool isFov(Vector3 vec1, Vector3 vec2, float radius) {
    float dx = vec1.x - vec2.x;
    float dy = vec1.y - vec2.y;
    return (dx*dx + dy*dy) <= (radius * radius);
}

void *GetClosestEnemy()
{
    try
    {
        float shortestDistance = 9999.0f;
        void *closestEnemy = NULL;

        void *get_MatchGame = game_sdk->Curent_Match();
        if (!get_MatchGame) return NULL;
        void *LocalPlayer = game_sdk->GetLocalPlayer(get_MatchGame);
        if (!LocalPlayer || !game_sdk->Component_GetTransform(LocalPlayer)) return NULL;
        if (!Vars.Enable) return NULL;

        if (Vars.fastfire) {
            void* PlayerAttributes = *(void**)((uint64_t)LocalPlayer + 0x768);
            if (PlayerAttributes) {
                *(float *)((long)PlayerAttributes + 0x2C0) = 0.18f;
                *(float *)((uintptr_t)PlayerAttributes + 0x260) = 0.3f;
            }
        } else {
            void* PlayerAttributes = *(void**)((uint64_t)LocalPlayer + 0x768);
            if (PlayerAttributes) {
                *(float *)((long)PlayerAttributes + 0x2C0) = 1.0f;
                *(float *)((uintptr_t)PlayerAttributes + 0x260) = 1.3f;
            }
        }

        if(Vars.noreload){
            void* PlayerAttributes = *(void**)((uint64_t)LocalPlayer + 0x768);
            if (PlayerAttributes) *(bool *)((long)PlayerAttributes + 0x111) = true;
        }else{
            void* PlayerAttributes = *(void**)((uint64_t)LocalPlayer + 0x768);
            if (PlayerAttributes) *(bool *)((long)PlayerAttributes + 0x111) = false;
        }

        Dictionary<uint8_t *, void **> *players = *(Dictionary<uint8_t *, void **> **)((long)get_MatchGame + oxo("0x148"));
        if (!players) return NULL;

        for (int u = 0; u < players->getSize(); u++)
        {
            void *Player = players->getValues()[u];
            if (!Player || Player == LocalPlayer) continue;
            if (!game_sdk->get_MaxHP(Player)) continue;
            if (game_sdk->get_IsDieing(Player)) continue;
            if (game_sdk->get_isLocalTeam(Player)) continue;

            Vector3 PlayerPos = getPosition(Player);
            if (PlayerPos.x == 0.0f && PlayerPos.y == 0.0f && PlayerPos.z == 0.0f) continue;

            Vector3 LocalPlayerPos = getPosition(LocalPlayer);
            ImVec2 screenPos = Camera$$WorldToScreen::Regular(PlayerPos);
            bool isFov1 = isFov(Vector3(screenPos.x, screenPos.y),
                                Vector3(ImGui::GetIO().DisplaySize.x / 2, ImGui::GetIO().DisplaySize.y / 2),
                                Vars.AimFov);
            float distance = Vector3::Distance(LocalPlayerPos, PlayerPos);
            if (distance < 200)
            {
                void *cam = game_sdk->get_camera();
                if (!cam) continue;
                void *camTF = game_sdk->Component_GetTransform(cam);
                if (!camTF) continue;

                Vector3 targetDir = Vector3::Normalized(PlayerPos - LocalPlayerPos);
                float angle = Vector3::Angle(targetDir, game_sdk->GetForward(camTF)) * 100.0f;
                if (angle <= Vars.AimFov && isFov1 && angle < shortestDistance)
                {
                    if (isVisibleCached(Player))
                    {
                        shortestDistance = angle;
                        closestEnemy = Player;
                    }
                }
            }
        }
        return closestEnemy;
    }
    catch (...) { return NULL; }
}

// ==========================================================================
// GetClosestEnemy360 — KHÔNG check FOV/góc camera. Range: 400m
// Tìm địch mọi hướng (trước/sau/trái/phải), chỉ cần: còn sống, khác team,
// trong 400m, và raycast camera→đầu địch không bị chắn.
// ==========================================================================
void *GetClosestEnemy360()
{
    try
    {
        float shortestDistance = 99999.0f;
        void *closestEnemy = NULL;

        void *get_MatchGame = game_sdk->Curent_Match();
        if (!get_MatchGame) return NULL;
        void *LocalPlayer = game_sdk->GetLocalPlayer(get_MatchGame);
        if (!LocalPlayer || !game_sdk->Component_GetTransform(LocalPlayer)) return NULL;

        Dictionary<uint8_t *, void **> *players = *(Dictionary<uint8_t *, void **> **)((long)get_MatchGame + oxo("0x148"));
        if (!players) return NULL;

        Vector3 LocalPlayerPos = getPosition(LocalPlayer);

        for (int u = 0; u < players->getSize(); u++)
        {
            void *Player = players->getValues()[u];
            if (!Player || Player == LocalPlayer) continue;
            if (!game_sdk->get_MaxHP(Player)) continue;
            if (game_sdk->get_IsDieing(Player)) continue;
            if (game_sdk->get_isLocalTeam(Player)) continue;

            Vector3 PlayerPos = getPosition(Player);
            if (PlayerPos.x == 0.0f && PlayerPos.y == 0.0f && PlayerPos.z == 0.0f) continue;

            float distance = Vector3::Distance(LocalPlayerPos, PlayerPos);
            if (distance > 400.0f) continue;            // ✅ 400m
            if (distance >= shortestDistance) continue;

            if (isVisibleCached(Player)) {
                shortestDistance = distance;
                closestEnemy = Player;
            }
        }
        return closestEnemy;
    }
    catch (...) { return NULL; }
}

#include "aimkill.h"
#include "send108.h"

// ==========================================================================
// AIM 360 — hook GetAimRotation + GetAuxAimRotation
// ==========================================================================

struct Aim360Quat { float x, y, z, w; };

static Aim360Quat g_aim360Quat   = {0.f, 0.f, 0.f, 1.f};
static void*      g_aim360Player = nullptr;
static bool       g_aim360Armed  = false;

static void RoseLookQuat(float nx, float ny, float nz, float rx, float ry, float rz,
                         float &o0, float &o1, float &o2, float &o3) {
    const double kEps = 1e-10;
    float s6 = ny*ny + nx*nx + nz*nz;
    float s16 = sqrtf(s6);
    float s7 = 0.f, s17 = 0.f;
    if (s16 == 0.f) { s6 = 0.f; s7 = 0.f; s16 = 0.f; }
    else { s6 = nx/s16; s7 = ny/s16; s16 = nz/s16; }
    float refLen = sqrtf(ry*ry + rx*rx + rz*rz);
    if (refLen == 0.f) { ry = 0.f; rz = 0.f; }
    else { s17 = rx/refLen; ry = ry/refLen; rz = rz/refLen; }
    float s18 = s7*s7 + s6*s6 + s16*s16;
    if ((double)s18 < kEps) { o0=o1=o2=o3=0.f; return; }
    float ref2 = ry*ry + s17*s17 + rz*rz;
    if ((double)ref2 < kEps) { o0=o1=o2=o3=0.f; return; }
    float dot = ry*s7 + s17*s6 + s16*rz;
    if ((double)(1.f - fabsf(dot)) < kEps) {
        float s4 = s16, s5 = sqrtf(s18);
        float s1 = (s5 != 0.f) ? s4/s5 : 0.f;
        if ((double)fabsf(s1 + 1.f) < 0.00001) { o0=0.f; o1=s1; o2=0.f; o3=0.f; return; }
        float q1 = s7, q3 = s6, q2 = 0.f;
        s4 = s4 + s5;
        float n = sqrtf(q3*q3 + q1*q1 + q2*q2 + s4*s4);
        if (n == 0.f) { o0=o1=o2=o3=0.f; return; }
        o0=q1/n; o1=q3/n; o2=q2/n; o3=s4/n; return;
    }
    float cx = ry*s16 - rz*s7;
    float cy = rz*s6 - s17*s16;
    float cz = s17*s7 - ry*s6;
    float clen = sqrtf(cx*cx + cy*cy + cz*cz);
    if (clen == 0.f) { cx = cy = cz = 0.f; }
    else { cx/=clen; cy/=clen; cz/=clen; }
    float dxc = s7*cz - cy*s16;
    float dyc = s16*cx - cz*s6;
    float dzc = s6*cy - cx*s7;
    float tr = cx + dyc + s16;
    if (tr > 0.f) {
        float w = 0.5f*sqrtf(tr + 1.f);
        float scale = (w != 0.f) ? 1.f/(w*4.f) : 0.f;
        o0=(dzc-s7)*scale; o1=(s6-cz)*scale; o2=(cy-dxc)*scale; o3=w; return;
    }
    if (cx >= dyc && cx >= s16) {
        float half = 0.5f*sqrtf(cx + 1.f - dyc - s16);
        float scale = (half != 0.f) ? 1.f/(half*4.f) : 0.f;
        o0=half; o1=(cy+dxc)*scale; o2=(s6+cz)*scale; o3=(dzc-s7)*scale; return;
    }
    if (dyc > s16) {
        float half = 0.5f*sqrtf(1.f - cx + dyc - s16);
        float scale = (half != 0.f) ? 1.f/(half*4.f) : 0.f;
        o0=(cy+dxc)*scale; o1=half; o2=(s7+dzc)*scale; o3=(s6-cz)*scale; return;
    }
    float half = 0.5f*sqrtf(1.f - cx - dyc + s16);
    float scale = (half != 0.f) ? 1.f/(half*4.f) : 0.f;
    o0=(s6+cz)*scale; o1=(s7+dzc)*scale; o2=half; o3=(cy-dxc)*scale;
}

static Aim360Quat compute_original_quat(void *player) {
    if (player) {
        void* tf = game_sdk->Component_GetTransform(player);
        if (tf) {
            Vector3 fwd = game_sdk->GetForward(tf);
            if (!(fwd.x == 0.f && fwd.y == 0.f && fwd.z == 0.f)) {
                Quaternion q = Quaternion::LookRotation(fwd, Vector3(0, 1, 0));
                return Aim360Quat{ q.x, q.y, q.z, q.w };
            }
        }
    }
    return Aim360Quat{0.f, 0.f, 0.f, 1.f};
}

static Aim360Quat hook_GetAimRotation(void *player) {
    if (Vars.AimKillSend && g_aim360Armed && player && player == g_aim360Player)
        return g_aim360Quat;
    return compute_original_quat(player);
}

static Aim360Quat hook_GetAuxAimRotation(void *player) {
    if (Vars.AimKillSend && g_aim360Armed && player && player == g_aim360Player)
        return g_aim360Quat;
    return compute_original_quat(player);
}

static void InstallAimKill360Hooks() {
    static bool hooked = false;
    if (hooked) return;
    hooked = true;

    hook(
        (void*[]){ (void*)getRealOffset(oxo("0x5624594")),
                   (void*)getRealOffset(oxo("0x56A55E8")) },
        (void*[]){ (void*)hook_GetAimRotation,
                   (void*)hook_GetAuxAimRotation },
        2
    );
}

static void UpdateAimRotHooks() {
    if (!Vars.AimKillSend) {
        g_aim360Armed = false;
        return;
    }

    InstallAimKill360Hooks();

    void *match = game_sdk->Curent_Match();
    void *local = match ? game_sdk->GetLocalPlayer(match) : nullptr;
    void *enemy = GetClosestEnemy360();   // đã check visible bên trong

    if (!local || !enemy) { g_aim360Armed = false; return; }

    Vector3 head = GetHeadPosition(enemy);
    Vector3 cam  = CameraMain(local);
    if (head == Vector3::zero() || cam == Vector3::zero()) {
        g_aim360Armed = false;
        return;
    }

    float dx = head.x - cam.x;
    float dy = head.y - cam.y;
    float dz = head.z - cam.z;
    float len2 = dx*dx + dy*dy + dz*dz;
    float q0 = 0.f, q1 = 0.f, q2 = 0.f, q3 = 1.f;
    if (!((double)len2 < 1e-10)) {
        float len = sqrtf(len2);
        float nx = 0.f, ny = 0.f, nz = 0.f;
        if (len != 0.f) { nx=dx/len; ny=dy/len; nz=dz/len; }
        float refy = (fabsf(ny) > 0.9990000128746033f) ? 0.f : 1.f;
        float refz = (fabsf(ny) > 0.9990000128746033f) ? 1.f : 0.f;
        RoseLookQuat(nx, ny, nz, 0.f, refy, refz, q0, q1, q2, q3);
    }

    g_aim360Quat   = {q0, q1, q2, q3};
    g_aim360Player = local;
    g_aim360Armed  = true;
}

void Tele10M() {
    if (!Vars.Enable || !Vars.telekill) return;
    void *match = game_sdk->Curent_Match();
    if (!match) return;
    void *local = game_sdk->GetLocalPlayer(match);
    if (!local || !game_sdk->Component_GetTransform(local)) return;
    void *localTF = game_sdk->Component_GetTransform(local);
    if (!localTF) return;

    Dictionary<uint8_t *, void **> *players = *(Dictionary<uint8_t *, void **> **)((long)match + oxo("0x148"));
    if (!players) return;

    Vector3 localPos = game_sdk->get_position(localTF);
    Vector3 forward = game_sdk->GetForward(localTF);
    float pullDistance = 2.0f;
    float maxDistance = 7.0f;
    double now = NowSeconds();

    for (int i = 0; i < players->getSize(); i++) {
        void *enemy = players->getValues()[i];
        if (!enemy || enemy == local) continue;
        void *enemyTF = game_sdk->Component_GetTransform(enemy);
        if (!enemyTF) continue;
        if (game_sdk->get_IsDieing(enemy)) continue;
        if (game_sdk->get_isLocalTeam(enemy)) continue;

        Vector3 enemyPos = game_sdk->get_position(enemyTF);
        float distance = Vector3::Distance(localPos, enemyPos);
        if (distance > maxDistance) continue;

        Vector3 targetPos = {
            localPos.x + (forward.x * pullDistance),
            localPos.y + 0.5f,
            localPos.z + (forward.z * pullDistance)
        };
        Transform_INTERNAL_SetPosition(enemyTF, Vvector3(targetPos.x, targetPos.y, targetPos.z));
        g_telePulled[enemy] = now;
    }
}

void RunUpPlayer() {
    if (!Vars.Nangdich) {
        baseGroundYMap.clear();
        lastBaseMatch = nullptr;
        return;
    }
    void *match = game_sdk->Curent_Match();
    if (!match) {
        baseGroundYMap.clear();
        lastBaseMatch = nullptr;
        return;
    }
    if (match != lastBaseMatch) {
        baseGroundYMap.clear();
        lastBaseMatch = match;
    }
    void *local = game_sdk->GetLocalPlayer(match);
    if (!local) return;

    auto *players = *(Dictionary<uint8_t*, void**>**)((long)match + 0x148);
    if (!players || players->getValues().empty()) return;
    auto playerList = players->getValues();
    int size = players->getSize();
    double now = NowSeconds();

    for (int i = 0; i < size; i++) {
        void *enemy = playerList[i];
        if (!enemy || enemy == local || game_sdk->get_isLocalTeam(enemy)) continue;
        if (game_sdk->get_IsDieing(enemy) || game_sdk->GetHp(enemy) <= 0) {
            baseGroundYMap.erase(enemy);
            continue;
        }
        void *enemyTF = game_sdk->Component_GetTransform(enemy);
        if (!enemyTF) continue;
        Vector3 enemyPos = game_sdk->get_position(enemyTF);
        if (enemyPos.x == 0.0f && enemyPos.y == 0.0f && enemyPos.z == 0.0f) continue;

        auto teleIt = g_telePulled.find(enemy);
        if (teleIt != g_telePulled.end() && (now - teleIt->second) < kTelePullReset) {
            baseGroundYMap[enemy] = enemyPos.y;
            continue;
        }

        auto it = baseGroundYMap.find(enemy);
        if (it == baseGroundYMap.end()) {
            baseGroundYMap[enemy] = enemyPos.y;
        } else {
            float baseY = it->second;
            if (enemyPos.y < baseY - 3.0f || enemyPos.y > baseY + 20.0f) {
                it->second = enemyPos.y;
            }
        }

        float baseY = baseGroundYMap[enemy];
        float targetY = baseY + 9.0f;
        float step = 0.6f;

        if (enemyPos.y < targetY) {
            enemyPos.y += step;
            if (enemyPos.y > targetY) enemyPos.y = targetY;
        } else {
            enemyPos.y = targetY;
        }
        Transform_INTERNAL_SetPosition(enemyTF, (Vvector3){enemyPos.x, enemyPos.y, enemyPos.z});
    }

    if (now - lastBaseCleanup > 5.0) {
        lastBaseCleanup = now;
        if (baseGroundYMap.size() > 64) {
            for (auto it = baseGroundYMap.begin(); it != baseGroundYMap.end(); ) {
                bool found = false;
                for (int i = 0; i < size; i++) {
                    if (playerList[i] == it->first) { found = true; break; }
                }
                if (!found) it = baseGroundYMap.erase(it); else ++it;
            }
        }
    }
}


struct TargetCache_t {
    void*   player        = nullptr;
    Vector3 bestRevealPos = Vector3(0, 0, 0);
    bool    hasBestPos    = false;
};

static TargetCache_t targetCache;



void RunAIRPlayer() {
    if (!Vars.AIRPlayer) return;
    void *match = game_sdk->Curent_Match();
    if (!match) return;
    void *local = game_sdk->GetLocalPlayer(match);
    if (!local) return;

    auto *players = *(Dictionary<uint8_t*, void**>**)((long)match + 0x148);
    if (!players) return;
    auto playerList = players->getValues();
    int size = players->getSize();

    static double lastSwitch = 0.0;
    static int    zigzagDir = 1;
    static std::unordered_map<void*, Vector3> g_baseCache;
    static std::unordered_map<void*, double>  g_baseTime;

    double now = NowSeconds();

    if (now - lastSwitch > 0.10) {
        zigzagDir = -zigzagDir;
        lastSwitch = now;
    }
    float offset = zigzagDir * 2.5f;   

    Vector3 localPos = getPosition(local);
    int pulled = 0;
    const int MAX_PULL = 5;

    for (int i = 0; i < size && pulled < MAX_PULL; i++) {
        void *enemy = playerList[i];
        if (!enemy || enemy == local) continue;
        if (game_sdk->get_isLocalTeam(enemy)) continue;
        if (game_sdk->get_IsDieing(enemy) || game_sdk->GetHp(enemy) <= 0) continue;
        void *enemyTF = game_sdk->Component_GetTransform(enemy);
        if (!enemyTF) continue;

        Vector3 enemyPos = game_sdk->get_position(enemyTF);
        float dist = Vector3::Distance(localPos, enemyPos);
        if (dist < 1.0f || dist > 200.0f) continue;

        double lastBaseUpd = g_baseTime.count(enemy) ? g_baseTime[enemy] : 0.0;
        if (now - lastBaseUpd > 0.5 || !g_baseCache.count(enemy)) {
            g_baseCache[enemy] = enemyPos;
            g_baseTime[enemy]  = now;
        }

        Vector3 base = g_baseCache[enemy];

        Vector3 newPos = base;
        newPos.x += offset;

        Transform_INTERNAL_SetPosition(enemyTF, (Vvector3){newPos.x, newPos.y, newPos.z});
        pulled++;
    }

    if (g_baseCache.size() > 20) {
        for (auto it = g_baseCache.begin(); it != g_baseCache.end(); ) {
            bool found = false;
            for (int i = 0; i < size; i++) {
                if (playerList[i] == it->first) { found = true; break; }
            }
            if (!found) {
                g_baseTime.erase(it->first);
                it = g_baseCache.erase(it);
            } else ++it;
        }
    }
}


void underNoFake() {
    if (!Vars.Enable || !Vars.Underground) {
        g_underCameraAdjusted = false;
        g_underLocalOriginalY  = 0.0f;
        enemyOriginalY.clear();
        return;
    }

    void *match = game_sdk->Curent_Match();
    if (!match) return;

    void *local = game_sdk->GetLocalPlayer(match);
    if (!local || !game_sdk->Component_GetTransform(local)) return;

    void *localTF = game_sdk->Component_GetTransform(local);
    if (!localTF) return;

    Vector3 localPos = game_sdk->get_position(localTF);

    if (g_underLocalOriginalY == 0.0f) {
        g_underLocalOriginalY = localPos.y;
    }

    void *camTF = game_sdk->Component_GetTransform(game_sdk->get_camera());
    if (camTF && !g_underCameraAdjusted) {
        Vector3 camPos = game_sdk->get_position(camTF);
        camPos.y -= 3.27f;
        Transform_INTERNAL_SetPosition(camTF, Vvector3(camPos.x, camPos.y, camPos.z));
        g_underCameraAdjusted = true;
    }

    float targetY = g_underLocalOriginalY - 3.0f;
    if (fabs(localPos.y - targetY) > 0.1f) {
        Transform_INTERNAL_SetPosition(localTF,
            Vvector3(localPos.x, targetY, localPos.z));
    }

    Dictionary<uint8_t *, void **> *players =
        *(Dictionary<uint8_t *, void **> **)((long)match + oxo("0x148"));
    if (!players || players->getValues().empty()) return;

    int size = players->getSize();
    auto playerList = players->getValues();

    for (int i = 0; i < size; i++) {
        void *enemy = playerList[i];

        if (!enemy || enemy == local) continue;
        if (!game_sdk->Component_GetTransform(enemy)) continue;
        if (!game_sdk->get_MaxHP(enemy)) continue;
        if (game_sdk->get_IsDieing(enemy)) continue;
        if (game_sdk->GetHp(enemy) <= 0) continue;
        if (game_sdk->get_isLocalTeam(enemy)) continue;

        void *enemyTF = game_sdk->Component_GetTransform(enemy);
        if (!enemyTF) continue;
        Vector3 enemyPos = game_sdk->get_position(enemyTF);

        if (enemyOriginalY.find(enemy) == enemyOriginalY.end()) {
            enemyOriginalY[enemy] = enemyPos.y;
        }

        float baseY = enemyOriginalY[enemy];
        if (fabs(enemyPos.y - baseY) > 15.0f) {
            enemyOriginalY[enemy] = enemyPos.y;
            baseY = enemyPos.y;
        }

        float enemyTargetY = baseY - 5.0f;

        if (fabs(enemyPos.y - enemyTargetY) > 0.1f) {
            Transform_INTERNAL_SetPosition(enemyTF,
                Vvector3(enemyPos.x, enemyTargetY, enemyPos.z));
        }
    }
}

void *getItransform(void *itransform) {
    if (!itransform) return nullptr;
    void * (*_itransformNode)(void *_this) = (void*(*)(void*))getRealOffset(0x6B4964C);
    return _itransformNode(itransform);
}

static float get_Range(void *pthis) {
    if (!pthis) return 0.0f;
    return ((float (*)(void *))getRealOffset(ENCRYPTOFFSET("0x5BED0A8")))(pthis);
}

bool isEnemyInRangeWeapon(void *player, void *enemy, void* weapon) {
    if (player != nullptr && enemy != nullptr && weapon != nullptr) {
        Vector3 EnemyHeadPosition = GetHeadPosition(enemy);
        Vector3 PlayerHeadPosition = GetHeadPosition(player);
        float distance = Vector3::Distance(PlayerHeadPosition, EnemyHeadPosition);
        float range = get_Range(weapon);
        if (distance <= range) return true;
    }
    return false;
}

Vector3 GetHipPosition(void* player) {
    if (!player) return Vector3::zero();
    void *HipITF= *(void **)((uint64_t) player + 0x6A8);
    if (!HipITF) return Vector3::zero();
    void *HipTF = getItransform(HipITF);
    return tanghinh::Transform_GetPosition(HipTF);
}

bool autoFireHook(void* _this) {
    (void)_this;

    if (!Vars.AutoFire) return false;

    uint64_t cached = g_autoFireTarget.load(std::memory_order_relaxed);
    if (!cached) return false;
    void* closestEnemy = (void*)cached;

    void *match = game_sdk->Curent_Match();
    if (!match) return false;

    void *local = game_sdk->GetLocalPlayer(match);
    if (!local) return false;

    if (game_sdk->get_IsDieing(closestEnemy)) return false;
    if (!isVisibleCached(closestEnemy)) return false;

    double now = NowSeconds();
    double last = g_lastAutoFireShot.load(std::memory_order_relaxed);
    float delay = Vars.AutoFireDelay;
    if (delay < 0.001f) delay = 0.001f;
    if (now - last < delay) return false;
    g_lastAutoFireShot.store(now, std::memory_order_relaxed);

    void* weapon = GetWeaponOnHand1(local);
    if (weapon) {
        *(bool *)((long)weapon + 0x899) = false;
        *(bool *)((long)weapon + 0x898) = false;
    }

    return true;
}

void initAutoFireHook(void) {
    static bool hookInitialized = false;
    if (hookInitialized) return;
    hookInitialized = true;

    hook(
        (void*[]) {
            (void*)getRealOffset(oxo("0x56D4758")),
        },
        (void*[]) {
            (void*)autoFireHook,
        },
        1
    );
}

void initDoubleGunHook(void) {
    static bool hookInitialized = false;
    if (hookInitialized) return;
    hookInitialized = true;

    hook(
        (void*[]) {
            (void*)getRealOffset(oxo("0x5BECF18")),
            (void*)getRealOffset(oxo("0x5636E60")),
        },
        (void*[]) {
            (void*)DOUBLE,
            (void*)InSwapWeaponCD,
        },
        2
    );
}

void initResetGuestHook(void) {
    static bool done = false;
    if (done) return;
    done = true;

    hook(
        (void*[]){ (void*)getRealOffset(oxo("0x507F3A0")) },
        (void*[]){ (void*)resetguesthook },
        1
    );
}

static void* g_frameMatch       = nullptr;
static void* g_frameLocalPlayer = nullptr;

static void UpdateFrameCache() {
    g_frameMatch       = game_sdk->Curent_Match();
    g_frameLocalPlayer = g_frameMatch ? game_sdk->GetLocalPlayer(g_frameMatch) : nullptr;
}

void ProcessAimbot() {
    bool wantTarget = Vars.AutoFire || Vars.Aimbot || Vars.SilentAim;
    void* closestEnemy = wantTarget ? GetClosestEnemy() : nullptr;

    g_autoFireTarget.store(Vars.AutoFire ? (uint64_t)closestEnemy : 0,
                           std::memory_order_relaxed);

    if (!Vars.Aimbot && !Vars.SilentAim) return;
    void *CurrentMatch = g_frameMatch;
    if (!CurrentMatch) return;
    void *LocalPlayer = g_frameLocalPlayer;
    if (!LocalPlayer || !game_sdk->Component_GetTransform(LocalPlayer)) return;
    if (!closestEnemy || !game_sdk->Component_GetTransform(closestEnemy)) {
        ClearSilentStateInternal();
        return;
    }

    int effectiveHitbox = Vars.AimHitbox;
    if (Vars.AimRandomEnable) {
        static bool s_wasFiring = false;
        static int  s_shotIdx   = 0;
        bool firingNow = game_sdk->get_IsFiring(LocalPlayer);
        if (firingNow && !s_wasFiring) s_shotIdx = (s_shotIdx + 1) & 3;
        s_wasFiring = firingNow;

        bool headShot = false;
        switch (Vars.AimRandomMode) {
            case 0: headShot = (s_shotIdx == 0); break;
            case 1: headShot = (s_shotIdx == 0 || s_shotIdx == 2); break;
            default: headShot = true; break;
        }
        effectiveHitbox = headShot ? 0 : 2;
    }

    Vector3 EnemyLocation = GetHitboxPosition(closestEnemy, effectiveHitbox);
    if (EnemyLocation == Vector3::zero()) return;
    Vector3 PlayerLocation = CameraMain(LocalPlayer);
    if (PlayerLocation == Vector3::zero()) return;

    bool IsScopeOn = game_sdk->get_IsSighting(LocalPlayer);
    bool IsFiring = game_sdk->get_IsFiring(LocalPlayer);
    bool shouldAim =
        (Vars.AimWhen == 0) ||
        (Vars.AimWhen == 1 && IsFiring) ||
        (Vars.AimWhen == 2 && IsScopeOn) ||
        (Vars.AimWhen == 3 && (IsFiring || IsScopeOn));

    if (Vars.Aimbot && shouldAim && (!Vars.VisibleCheck || isVisibleCached(closestEnemy))) {
        if (game_sdk->get_IsDieing(closestEnemy) && Vars.IgnoreKnocked) {
            float shortestDistance = 9999.0f;
            void *newTarget = NULL;
            Dictionary<uint8_t *, void **> *players = *(Dictionary<uint8_t *, void **> **)((long)CurrentMatch + oxo("0x148"));
            if (players) {
                for (int u = 0; u < players->getSize(); u++) {
                    void *Player = players->getValues()[u];
                    if (!Player || Player == LocalPlayer || !game_sdk->get_MaxHP(Player) || game_sdk->get_isLocalTeam(Player) || Player == closestEnemy) continue;
                    if (Vars.IgnoreKnocked && game_sdk->get_IsDieing(Player)) continue;
                    if (Vars.VisibleCheck && !isVisibleCached(Player)) continue;
                    Vector3 PlayerPos = GetHitboxPosition(Player, effectiveHitbox);
                    float distance = Vector3::Distance(PlayerLocation, PlayerPos);
                    if (distance < 300 && distance < shortestDistance) {
                        shortestDistance = distance;
                        newTarget = Player;
                    }
                }
            }
            if (newTarget) {
                EnemyLocation = GetHitboxPosition(newTarget, effectiveHitbox);
                closestEnemy = newTarget;
            } else return;
        }

        bool inRange = true;
        ImVec2 EnemyScreenPos;
        bool w2sEnemy = false;
        if (Vars.AimMode == 1 || Vars.AimMode == 2) {
            EnemyScreenPos = Camera$$WorldToScreen::Checker(EnemyLocation, w2sEnemy);
            if (!w2sEnemy) inRange = false;
            else if (Vars.AimMode == 2) {
                ImVec2 center = ImVec2(ImGui::GetIO().DisplaySize.x / 2, ImGui::GetIO().DisplaySize.y / 2);
                float dx = EnemyScreenPos.x - center.x;
                float dy = EnemyScreenPos.y - center.y;
                float dist = sqrtf(dx*dx + dy*dy);
                inRange = (dist <= Vars.AimFov);
            }
        }
        if (inRange) {
            Quaternion TargetLook = GetRotationToTheLocation(EnemyLocation, 0.05f, PlayerLocation);
            game_sdk->set_aim(LocalPlayer, TargetLook);
        }
    }

    if (Vars.SilentAim && closestEnemy) {
        if (shouldAim) {
            SilentAimActivate(LocalPlayer, closestEnemy, effectiveHitbox);
        } else {
            ClearSilentStateInternal();
        }
    } else {
        ClearSilentStateInternal();
    }
}

void get_players()
{
    ImDrawList *draw_list = ImGui::GetBackgroundDrawList();
    if (!draw_list) return;
    if (!Vars.Enable) return;
    if (!game_sdk) return;

    {
        static double s_lastCleanup = 0.0;
        double nowS_ = NowSeconds();
        if (nowS_ - s_lastCleanup > 1.0) {
            CleanupVisCache();
            s_lastCleanup = nowS_;
        }
    }

    int totalRealCount = 0;
    int totalBotCount = 0;
    double nowFrame = NowSeconds();

    try
    {
        UpdateFrameCache();
        Tele10M();
        ProcessAimbot();

        // ✅ AimKillSend: aim 360 (mọi hướng, 400m) + 108 + 106
        if (Vars.AimKillSend) {
            UpdateAimRotHooks();

            void *match = game_sdk->Curent_Match();
            void *local = match ? game_sdk->GetLocalPlayer(match) : nullptr;
            void *enemy = GetClosestEnemy360();  // ← mọi hướng, 400m
            if (local && enemy) {
                Send108(local, enemy);
                StartAimkill();
            }
        } else {
            g_aim360Armed = false;
        }

        RunAIRPlayer();
        RunUpPlayer();
        underNoFake();

        void *current_Match = g_frameMatch;
        if (!current_Match) return;
        void *LocalPlayer = g_frameLocalPlayer;
        if (!LocalPlayer) return;

        FakeName_Update(LocalPlayer);

        if (Vars.camxa) {
            void* FollowCamera = *(void**)((uint64_t)LocalPlayer + 0x690);
            if (FollowCamera) *(float*)((uint64_t)FollowCamera + 0x84) = Vars.CamXaValue;
        } else {
            void* FollowCamera = *(void**)((uint64_t)LocalPlayer + 0x690);
            if (FollowCamera) *(float*)((uint64_t)FollowCamera + 0x84) = 1.0f;
        }

        Dictionary<uint8_t *, void **> *players = *(Dictionary<uint8_t *, void **> **)((long)current_Match + 0x148);
        if (!players) return;
        void *camera = game_sdk->get_camera();
        if (!camera) return;

        Vector3 pos2 = getPosition(LocalPlayer);
        void* cameraTransform = game_sdk->Component_GetTransform(camera);
        if (!cameraTransform) return;
        Vector3 viewpos = game_sdk->get_position(cameraTransform);
        Vector3 viewdir = Vector3::zero();
        if (Vars.OOF) viewdir = game_sdk->GetForward(cameraTransform);

        int playerCount = players->getSize();
        ImVec2 displaySize = ImGui::GetIO().DisplaySize;

        for (int u = 0; u < playerCount; u++)
        {
            void *closestEnemy = players->getValues()[u];
            if (!closestEnemy || closestEnemy == LocalPlayer) continue;
            void* enemyTransform = game_sdk->Component_GetTransform(closestEnemy);
            if (!enemyTransform) continue;

            int hp = game_sdk->GetHp(closestEnemy);
            int maxhp = game_sdk->get_MaxHP(closestEnemy);
            if (maxhp <= 0 || hp <= 0) continue;
            if (game_sdk->get_isLocalTeam(closestEnemy)) continue;

            Vector3 pos = getPosition(closestEnemy);
            auto airIt = g_airSnappedPos.find(closestEnemy);
            if (airIt != g_airSnappedPos.end() && (nowFrame - airIt->second.t) < kAirSnapTTL) {
                pos = airIt->second.pos;
            }

            if (pos.x == 0.0f && pos.y == 0.0f && pos.z == 0.0f) continue;
            float distance = Vector3::Distance(pos, pos2);
            if (distance > Vars.espDrawDistance) continue;

            totalRealCount++;

            bool isDieing = game_sdk->get_IsDieing(closestEnemy);
            bool isVis = isDieing ? false : isVisibleCached(closestEnemy);

            ImColor renderColor;
            if (isDieing) renderColor = ImColor(255, 40, 40);
            else if (isVis) renderColor = ImColor(0, 245, 255);
            else renderColor = ImColor(152, 251, 152);

            bool w2sc;
            Vector3 headPos = pos + Vector3(0, 1.45f, 0);
            ImVec2 pos_3 = Camera$$WorldToScreen::Checker(pos, w2sc);
            if (!w2sc && !Vars.OOF) { continue; }

            bool needRect = w2sc && (Vars.Box || Vars.lines || Vars.Name || Vars.Health || Vars.Distance);
            ImVec2 top_pos = ImVec2(0,0), bot_pos = ImVec2(0,0);
            ImRect rect(ImVec2(0,0), ImVec2(0,0));
            if (needRect) {
                top_pos = Camera$$WorldToScreen::Regular(headPos);
                bot_pos = Camera$$WorldToScreen::Regular(pos);
                top_pos.y += 4.0f;
                float height = fabs(bot_pos.y - top_pos.y);
                if (isDieing) { height *= 0.35f; top_pos.y = bot_pos.y - height; }
                float calculatedPosition = height * 0.22f;
                rect = ImRect(ImVec2(bot_pos.x - calculatedPosition, top_pos.y),
                              ImVec2(bot_pos.x + calculatedPosition, bot_pos.y));
            }

            if (needRect)
            {
                if (Vars.lines) {
                    draw_list->AddLine(ImVec2(displaySize.x / 2, 0.0f), ImVec2(rect.GetCenter().x, rect.Min.y), ImColor(Vars.espLineColor[0], Vars.espLineColor[1], Vars.espLineColor[2], Vars.espLineColor[3]), 1.0f);
                }
                if (Vars.Box) {
                    if (isDieing) draw_list->AddRect(rect.Min, rect.Max, ImColor(255, 0, 0), 0.0f, 0, 0.3f);
                    else draw_list->AddRect(rect.Min, rect.Max, ImColor(Vars.espBoxColor[0], Vars.espBoxColor[1], Vars.espBoxColor[2], Vars.espBoxColor[3]), 0.0f, 0, 1.0f);
                    if (Vars.Outline) {
                        draw_list->AddRect(rect.Min - ImVec2(1, 1), rect.Max + ImVec2(1, 1), ImColor(0, 0, 0), 0.0f, 0, 1.0f);
                        draw_list->AddRect(rect.Min + ImVec2(1, 1), rect.Max - ImVec2(1, 1), ImColor(0, 0, 0), 0.0f, 0, 1.0f);
                    }
                }
                if (Vars.Name) {
                    auto pname = game_sdk->name(closestEnemy);
                    if (pname) {
                        std::string namestr = pname->toCPPString();
                        if (!namestr.empty()) {
                            ImFont* font = ImGui::GetFont();
                            float fontSize = 9.0f;
                            auto &nc = g_nameSizeCache[closestEnemy];
                            if (nc.lastName != namestr) {
                                nc.size = font->CalcTextSizeA(fontSize, FLT_MAX, 0, namestr.c_str());
                                nc.lastName = namestr;
                            }
                            ImVec2 name_pos = { rect.Max.x + 2.0f, rect.Min.y };
                            draw_list->AddText(font, fontSize, name_pos, ImColor(255, 255, 255, 255), namestr.c_str());
                        }
                    }
                }
                if (Vars.Health) {
                    float hpRatio = (float)hp / (float)maxhp;
                    hpRatio = hpRatio < 0.0f ? 0.0f : (hpRatio > 1.0f ? 1.0f : hpRatio);
                    float barX = rect.Min.x - 5;
                    float barH = rect.GetHeight();
                    ImVec2 barBg1 = ImVec2(barX, rect.Min.y);
                    ImVec2 barBg2 = ImVec2(barX + 2, rect.Max.y);
                    draw_list->AddRectFilled(barBg1, barBg2, ImColor(40, 40, 40, 200));
                    ImColor hpColor = hpRatio > 0.5f ? ImColor(0, 255, 0)
                                    : hpRatio > 0.25f ? ImColor(255, 255, 0)
                                    : ImColor(255, 0, 0);
                    ImVec2 barFg1 = ImVec2(barX, rect.Max.y - barH * hpRatio);
                    ImVec2 barFg2 = ImVec2(barX + 2, rect.Max.y);
                    draw_list->AddRectFilled(barFg1, barFg2, hpColor);
                    if (Vars.Outline) draw_list->AddRect(barBg1, barBg2, ImColor(0, 0, 0), 0, 0, 1);
                }
                if (Vars.Distance) {
                    char distBuf[16];
                    snprintf(distBuf, sizeof(distBuf), "%dM", static_cast<int>(distance));
                    ImVec2 distance_pos = { rect.Max.x + 4, rect.Min.y };
                    AddText(pixel_smol, 8, false, true, distance_pos, ImColor(255, 255, 255), distBuf);
                }
            }
            if (w2sc && Vars.skeleton) DrawSkeleton(closestEnemy, draw_list);

            if (Vars.OOF) {
                if ((pos_3.x < 0 || pos_3.x > displaySize.x) || (pos_3.y < 0 || pos_3.y > displaySize.y) || !w2sc) {
                    Vector3 targetdir = Vector3::Normalized(pos - viewpos);
                    float viewangle = atan2(viewdir.z, viewdir.x) * (180.0f / 3.14159265f);
                    float targetangle = atan2(targetdir.z, targetdir.x) * (180.0f / 3.14159265f);
                    float angle = targetangle - viewangle;
                    while (angle < 0) angle += 360; while (angle > 360) angle -= 360;
                    angle = 360 - angle; angle -= 90;
                    float rad = angle * (3.14159265f / 180.0f);
                    float radius = 180.0f;
                    float triangle_length = 20.0f; float triangle_width = 0.12f;
                    ImVec2 center(displaySize.x / 2, displaySize.y / 2);
                    ImVec2 p1(center.x + cosf(rad) * radius, center.y + sinf(rad) * radius);
                    ImVec2 p2(center.x + cosf(rad - triangle_width) * (radius - triangle_length), center.y + sinf(rad - triangle_width) * (radius - triangle_length));
                    ImVec2 p3(center.x + cosf(rad + triangle_width) * (radius - triangle_length), center.y + sinf(rad + triangle_width) * (radius - triangle_length));
                    draw_list->AddTriangle(p1, p2, p3, renderColor, 2.0f);
                }
            }
        }
        if (Vars.ESPCount || Vars.enemycount) {
            char infoText[64];
            const char* label = (g_espLang == 1) ? "Ng\xc6\xb0\xe1\xbb\x9di ch\xc6\xa1i" : "Player";
            snprintf(infoText, sizeof(infoText), "%s : %d", label, totalRealCount + totalBotCount);
            ImGuiIO& io = ImGui::GetIO();
            const float fontSize = 32.0f;
            ImVec2 textSize = pixel_big->CalcTextSizeA(fontSize, FLT_MAX, 0.0f, infoText);
            ImVec2 pos(floorf(io.DisplaySize.x * 0.5f - textSize.x * 0.5f), floorf(40.0f));
            AddText(pixel_big, fontSize, false, false, pos, ImColor(255, 255, 255, 255), infoText);
        }
    } catch (...) { return; }
}

void aimbot()
{
    ImVec2 center = ImVec2(ImGui::GetIO().DisplaySize.x / 2, ImGui::GetIO().DisplaySize.y / 2);
    if (!Vars.Aimbot) return;
    ImDrawList *draw_list = ImGui::GetBackgroundDrawList();
    if (!draw_list) return;
    void *Match = game_sdk->Curent_Match();
    if (!Match) return;

    Vars.isAimFov = (Vars.AimMode == 2);
    if (Vars.isAimFov) {
        if (Vars.fovaimglow)
            drawcircleglow(draw_list, center, Vars.AimFov, ImColor(Vars.fovLineColor[0], Vars.fovLineColor[1], Vars.fovLineColor[2], Vars.fovLineColor[3]), 999, 1, 12);
        else
            draw_list->AddCircle(center, Vars.AimFov, ImColor(Vars.fovLineColor[0], Vars.fovLineColor[1], Vars.fovLineColor[2], Vars.fovLineColor[3]), 100);
    }
    void *LocalPlayer = game_sdk->GetLocalPlayer(Match);
    if (!LocalPlayer) return;
    void *playertarget = GetClosestEnemy();
    if (!playertarget) return;
}

void draw_watermark()
{
    std::string claw = oxorany("");
    static ImVec2 cachedSize = {-1, -1};
    if (cachedSize.x < 0) cachedSize = verdana_smol->calc_size(1, claw);
    ImVec2 text_size = cachedSize;
    ImVec2 text_pos(10, ImGui::GetIO().DisplaySize.y - text_size.y - 10);
    AddText(verdana_smol, 16, false, false, text_pos + ImVec2(1, 1), ImColor(0, 0, 0, 150), claw);
    static float hue = 0.0f;
    hue += ImGui::GetIO().DeltaTime * 0.1f;
    if (hue > 1.0f) hue = 0.0f;
    ImColor rainbow = ImColor::HSV(hue, 0.8f, 0.8f);
    AddText(verdana_smol, 16, false, false, text_pos, rainbow, claw);
    ImDrawList *draw_list = ImGui::GetBackgroundDrawList();
    draw_list->AddLine(
        ImVec2(text_pos.x, text_pos.y + text_size.y + 2),
        ImVec2(text_pos.x + text_size.x, text_pos.y + text_size.y + 2),
        rainbow, 2.0f);
}

void* SpinBotLoop(void* arg) {
    while (true) {
        if (Vars.SpinBotEnabled) {
            void* match = game_sdk->Curent_Match();
            if (match) {
                void* localPlayer = game_sdk->GetLocalPlayer(match);
                if (localPlayer) {
                    void* transform = game_sdk->Component_GetTransform(localPlayer);
                    if (transform) {
                        Vars.currentY += Vars.SpinBotSpeed;
                        if (Vars.currentY >= 360.0f) Vars.currentY = 0;
                        float rad = Vars.currentY * (M_PI / 180.0f);
                        Quaternion rot;
                        rot.x = 0;
                        rot.y = sinf(rad / 2);
                        rot.z = 0;
                        rot.w = cosf(rad / 2);
                        Transform_INTERNAL_SetRotation(transform, rot);
                    }
                }
            }
        }
        usleep(1000);
    }
    return NULL;
}