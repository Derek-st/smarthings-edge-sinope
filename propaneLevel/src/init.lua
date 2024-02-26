-- require st provided libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"
local url = require("socket.url")
local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local contact_sensor_defaults = require "st.zigbee.defaults.contactSensor_defaults"
local data_types = require "st.zigbee.data_types"
local common = require("common")
local device_management = require "st.zigbee.device_management"

local neturl = require('net.url')
local json = require('dkjson')
local cosock = require "cosock"
local http = cosock.asyncify "socket.http"
local ltn12 = require('ltn12')

-- require custom handlers from driver package
local discovery = require "discovery"







local function device_added(driver, device)
  log.info("[" .. device.id .. "] Adding new propaneLevel device")

end


local function info_changed(driver, device)
  log.info("[" .. device.id .. " info_changed handler")
--  device:send(device_management.build_bind_request(device, tempMeasurement.ID, self.environment_info.hub_zigbee_eui))
--  device:send(tempMeasurement.attributes.MeasuredValue:configure_reporting(device, 5, device.preferences.tempMaxInterval , 1))
    for capability_id, configs in pairs(common.get_cluster_configurations(device:get_manufacturer(),device)) do
        if device:supports_capability_by_id(capability_id) then
            for _, config in pairs(configs) do
                log.debug("Adding and configuring---------------------------------", config.reportable_change)
                device:add_configured_attribute(config)
                device:add_monitored_attribute(config)
            end
        end
    end
    
  device:configure()
end




local function refresh_handler(driver, device)
  log.info("[" .. device.id .. "] Refreshing propaneLevel device")

--device:emit_event(capabilities['digitclever52707.propaneLevel'].propaneLevel({value = 7}))
device:refresh()


for _ , cap in ipairs(capabilities['digitclever52707.propaneLevel']) do
	log.debug(cap.id)
end

end


local function device_init(driver, device)
  log.debug("[" .. device.id .. "] Initializing propaneLevel device")
--  #  device:configure()
  
    for capability_id, configs in pairs(common.get_cluster_configurations(device:get_manufacturer(),device)) do
        if device:supports_capability_by_id(capability_id) then
            for _, config in pairs(configs) do
		log.debug("Adding and configuring---------------------------------", config.reportable_change) 
                device:add_configured_attribute(config)
                device:add_monitored_attribute(config)
            end
        end
    end
  device:refresh()
  device:configure()
end

local function device_removed(driver, device)
  log.info("[" .. device.id .. "] Removing propaneLevel device")
  for timer in pairs(device.thread.timers) do
    device.thread:cancel_timer(timer)
  end
end

local can_handle = function(opts, driver, device)
    return device:get_manufacturer() == "Sinope Technologies"
end

local handlers = {
    global = {},
    cluster = {},
    attr = {  
	[zcl_clusters.AnalogInput.ID] = 
	{[zcl_clusters.AnalogInput.attributes.PresentValue.ID ]  = common.value_handler }
},
    --    [zcl_clusters.IASZone.ID] = {
    --        [zcl_clusters.IASZone.attributes.ZoneStatus.ID] = ias_zone_status_attr_handler
    --    } 
    zdo = {}
}




local tankDriverTemplate =  {
--  discovery = discovery.handle_discovery,
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
    removed = device_removed,
    infoChanged = info_changed
  },
     supported_capabilities = {
        capabilities.battery,
        capabilities.temperatureMeasurement,
        capabilities.refresh,
	capabilities['digitclever52707.propaneLevel']
    },

	   
   

	   
    zigbee_handlers = handlers 
--    ias_zone_configuration_method= constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
--   , capability_handlers = {
--
	, [capabilities.refresh.ID] = {
            [capabilities.refresh.commands.refresh.NAME] = refresh_handler }
 --   },
    , can_handle = can_handle

-- sub_drivers = { require("smartthings") } 
}


--Run driver
defaults.register_for_default_handlers(tankDriverTemplate, tankDriverTemplate.supported_capabilities)
local tankDriver = ZigbeeDriver("tankLevel", tankDriverTemplate)

tankDriver:run()










--    name = "Sinopé Manufacturer specific"
--    ep_attribute = "sinope_manufacturer_specific"
--    attributes = {
--        0x0003: ("firmware_number", t.uint16_t, True),
--        0x0004: ("firmware_version", t.CharacterString, True),
--        0x0200: ("unknown_attr_1", t.bitmap32, True),
--        0xFFFD: ("cluster_revision", t.uint16_t, True),
--    }

 --               1: {
 -- -              PROFILE_ID: zha_p.PROFILE_ID,
 --               DEVICE_TYPE: zha_p.DeviceType.ON_OFF_SWITCH,
 --               INPUT_CLUSTERS: [
  --                  Basic.cluster_id,
 --                   PowerConfiguration.cluster_id,
 --                   Identify.cluster_id,
 --                   AnalogInput.cluster_id,
 --                   PollControl.cluster_id,
 --                   TemperatureMeasurement.cluster_id,
  --                  Diagnostic.cluster_id,
   --                 SINOPE_MANUFACTURER_CLUSTER_ID,
  --              ],
  --              OUTPUT_CLUSTERS: [
   --                 Ota.cluster_id,
   --             ],
