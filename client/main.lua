local config = require 'config.client'
local lib = exports['ox_lib']
local playerState = LocalPlayer.state
local speedMultiplier = config.useMPH and 2.237 or 3.6
local minSpeeds = {
    unbuckled = config.minSpeedUnbuckled / speedMultiplier,
    buckled = config.minSpeedBuckled / speedMultiplier,
    harness = config.harness.minSpeed / speedMultiplier
}

-- Functions
local function playBuckleSound(seatbelt)
    qbx.loadAudioBank('audiodirectory/seatbelt_sounds')
    qbx.playAudio({
        audioName = seatbelt and 'carbuckle_left' or 'carunbuckle_left',
        audioRef = 'seatbelt_soundset',
        source = cache.ped
    })
    ReleaseNamedScriptAudioBank('audiodirectory/seatbelt_sounds')
end

local function toggleSeatbelt()
    if playerState.harness then
        lib.notify({
            title = 'Harness already on!',
            description = 'Take your harness off first!',
            type = 'error'
        })

        -- Original
        --exports.qbx_core:Notify(locale('error.harnesson'), 'error')
        return
    end
    local seatbeltOn = not playerState.seatbelt
    playerState.seatbelt = seatbeltOn
    SetFlyThroughWindscreenParams(seatbeltOn and minSpeeds.buckled or minSpeeds.unbuckled, 1.0, 17.0, 10.0)
    TriggerEvent('seatbelt:client:ToggleSeatbelt')
    playBuckleSound(seatbeltOn)
end

local function toggleHarness()
    local harnessOn = not playerState.harness
    playerState.harness = harnessOn
    TriggerEvent('seatbelt:client:ToggleSeatbelt')
    playBuckleSound(harnessOn)

    local canFlyThroughWindscreen = not harnessOn
    if config.harness.disableFlyingThroughWindscreen then
        SetPedConfigFlag(cache.ped, 32, canFlyThroughWindscreen) -- PED_FLAG_CAN_FLY_THRU_WINDSCREEN
    else
        local minSpeed = harnessOn and minSpeeds.harness or (playerState.seatbelt and minSpeeds.buckled or minSpeeds.unbuckled)
        SetFlyThroughWindscreenParams(minSpeed, 1.0, 17.0, 10.0)
    end
end

local function seatbelt()
    while cache.vehicle do
        local sleep = 1000
        if playerState.seatbelt or playerState.harness then
            sleep = 0
            DisableControlAction(0, 75, true)
            DisableControlAction(27, 75, true)
        end
        Wait(sleep)
    end
    playerState.seatbelt = false
    playerState.harness = false
end

-- Export
function HasHarness()
    return playerState.harness
end

--- @deprecated Use `state.seatbelt` instead
exports('HasHarness', HasHarness)

-- Main Thread
CreateThread(function()
    SetFlyThroughWindscreenParams(minSpeeds.unbuckled, 1.0, 17.0, 10.0)
end)

lib.onCache('vehicle', function()
    Wait(500)
    seatbelt()
end)

-- Events
RegisterNetEvent('qbx_seatbelt:client:UseHarness', function(ItemData)
    if playerState.seatbelt then
        lib.notify({
            title = 'Seatbelt already on!',
            description = 'Take your seatbelt off first!',
            type = 'error'
        })
        return
    end

    local class = GetVehicleClass(cache.vehicle)

    if not cache.vehicle or class == 8 or class == 13 or class == 14 then
        lib.notify({
            title = 'No vehicle found!',
            description = 'You need to be in a vehicle!',
            type = 'error'
        })
        return
    end

    if not playerState.harness then
        if lib.progressCircle({
            duration = 5000,
            label = 'Attaching Harness',
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {
                combat = true
            }
        }) then
            TriggerServerEvent('qbx_seatbelt:server:equip', ItemData.slot)
            toggleHarness()
        end
    else
        if lib.progressCircle({
            duration = 5000,
            label = 'Removing Harness',
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {
                combat = true
            }
        }) then
            toggleHarness()
        end
    end
end)

-- Register Key
lib.addKeybind({
    name = 'toggleseatbelt',
    description = 'Toggle Seatbelt',
    defaultKey = config.keybind,
    onPressed = function()
        if not cache.vehicle or IsPauseMenuActive() then return end
        local class = GetVehicleClass(cache.vehicle)
        if class == 8 or class == 13 or class == 14 then return end
        toggleSeatbelt()
    end
})
