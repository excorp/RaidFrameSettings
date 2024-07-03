local _, addonTable = ...
local addon = addonTable.addon

local module = addon:NewModule("DefensiveOverlay")

--------------------
--- Libs & Utils ---
--------------------

local Media = LibStub("LibSharedMedia-3.0")
local CR = addonTable.CallbackRegistry


local callback_id
function module:OnEnable()
  -- Get the database objects
  local db_obj = CopyTable(addon.db.profile.DefensiveOverlay)
  local db_obj_font_duration = CopyTable(addon.db.profile.DefensiveOverlayDurationFont)
  local db_obj_font_stack = CopyTable(addon.db.profile.DefensiveOverlayStackFont)
  -- Fetch DB values
  local path_to_duration_font = Media:Fetch("font", db_obj_font_duration.font)
  local path_to_stack_font = Media:Fetch("font", db_obj_font_stack.font)

  -- AuraFrame options
  local aura_frame_options = {
    -- Position
    anchor_point = db_obj.point,
    relative_point = db_obj.relative_point,
    offset_x = db_obj.offset_x,
    offset_y = db_obj.offset_y,
    -- Num indicators row*column
    num_indicators_per_row = db_obj.num_indicators_per_row,
    num_indicators_per_column = db_obj.num_indicators_per_column,
    -- Orientation
    direction_of_growth_vertical = db_obj.direction_of_growth_vertical,
    vertical_padding = db_obj.vertical_padding,
    direction_of_growth_horizontal = db_obj.direction_of_growth_horizontal,
    horizontal_padding = db_obj.horizontal_padding,
    -- Indicator size
    indicator_width = db_obj.indicator_width,
    indicator_height = db_obj.indicator_height,
    -- Indicator border
    indicator_border_thickness = db_obj.indicator_border_thickness,
    indicator_border_color = db_obj.indicator_border_color,
    -- Font: Duration
    path_to_duration_font = path_to_duration_font,
    duration_font_size = db_obj_font_duration.font_size,
    duration_font_outlinemode = db_obj_font_duration.font_outlinemode,
    duration_font_color = db_obj_font_duration.text_color,
    duration_font_point = db_obj_font_duration.point,
    duration_font_relative_point = db_obj_font_duration.relative_point,
    duration_font_offset_x = db_obj_font_duration.offset_x,
    duration_font_offset_y = db_obj_font_duration.offset_y,
    duration_font_shadow_color =  db_obj_font_duration.shadow_color,
    duration_font_shadow_offset_x = db_obj_font_duration.shadow_offset_x,
    duration_font_shadow_offset_y = db_obj_font_duration.shadow_offset_y,
    duration_font_horizontal_justification = db_obj_font_duration.horizontal_justification,
    duration_font_vertical_justification = db_obj_font_duration.vertical_justification,
    -- Font: Stack
    path_to_stack_font = path_to_stack_font,
    stack_font_size = db_obj_font_stack.font_size,
    stack_font_outlinemode = db_obj_font_stack.font_outlinemode,
    stack_font_color = db_obj_font_stack.text_color,
    stack_font_point = db_obj_font_stack.point,
    stack_font_relative_point = db_obj_font_stack.relative_point,
    stack_font_offset_x = db_obj_font_stack.offset_x,
    stack_font_offset_y = db_obj_font_stack.offset_y,
    stack_font_shadow_color =  db_obj_font_stack.shadow_color,
    stack_font_shadow_offset_x = db_obj_font_stack.shadow_offset_x,
    stack_font_shadow_offset_y = db_obj_font_stack.shadow_offset_y,
    stack_font_horizontal_justification = db_obj_font_stack.horizontal_justification,
    stack_font_vertical_justification = db_obj_font_stack.vertical_justification,
    -- Cooldown
    show_swipe = db_obj.show_swipe,
    reverse_swipe = db_obj.reverse_swipe,
    show_edge = db_obj.show_edge,
    -- Tooltip
    show_tooltip = db_obj.show_tooltip
  }

  -- Create a callback to create an aura frame when a new frame env is created.
  local function create_or_update_defensive_overlay(cuf_frame)
    if not cuf_frame.RFS_FrameEnvironment.aura_frames["DefensiveOverlay"] then
      cuf_frame.RFS_FrameEnvironment.aura_frames["DefensiveOverlay"] = addon:NewAuraFrame(cuf_frame)
    end
    cuf_frame.RFS_FrameEnvironment.aura_frames["DefensiveOverlay"]:Enable(aura_frame_options)
  end
  -- Place the callback in the callback table.
  addonTable.on_create_frame_env_callbacks["DefensiveOverlay"] = create_or_update_defensive_overlay

  -- Handle Aura Changes
  local function on_auras_changed(cuf_frame)
    cuf_frame.RFS_FrameEnvironment.aura_frames["DefensiveOverlay"]:Update(cuf_frame.RFS_FrameEnvironment.grouped_auras["DefensiveOverlay"])
  end

  -- Gather all wanted spellIds
  local defensive_spell_ids = {}
  for _, v in next, db_obj do
    if type(v) == "table" then
      for spell_id, should_display in next, v do
        if should_display then
          defensive_spell_ids[spell_id] = true
        end
      end
    end
  end

  -- Update the whitelist.
  addon:UpdateWhitelist()
  -- Register the defensive spell ids for DefensiveOverlay. The cuf_frames frame env will use this name as the update notifier event.
  addon:RegisterAuraGroup("DefensiveOverlay", defensive_spell_ids)
  -- Register the DefensiveOverlay callback
  callback_id = CR:RegisterCallback("DefensiveOverlay", on_auras_changed)

  addon:IterateRoster(function(cuf_frame)
    create_or_update_defensive_overlay(cuf_frame)
    if cuf_frame.unit and cuf_frame:IsShown() then
      addon:CreateOrUpdateAuraScanner(cuf_frame)
    end
  end, true)
end

function module:OnDisable()
  -- Update the whitelist.
  addon:UpdateWhitelist()
  -- Remove the callback in the callback table.
  addonTable.on_create_frame_env_callbacks["DefensiveOverlay"] = nil
  -- Unregister the callback
  CR:UnregisterCallback("DefensiveOverlay", callback_id)
  addon:UnregisterAuraGroup("DefensiveOverlay")
  -- Apply the changes to all frames currently displayed.
  local function hide_overlay(cuf_frame)
    cuf_frame.RFS_FrameEnvironment.aura_frames["DefensiveOverlay"]:Disable()
    if cuf_frame.unit and cuf_frame:IsShown() then
      addon:CreateOrUpdateAuraScanner(cuf_frame)
    end
  end
  addon:IterateRoster(hide_overlay, true)
end


