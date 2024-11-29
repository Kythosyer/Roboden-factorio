--[[

Copyright 2024 Kythosyer

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]] --
-- Raiguard is amazing, best library around for events.
local flib_gui = require("__flib__.gui")

-- GUI Setup
local gui = {}

local mode = "logistic"
local alerts = false
function gui.build(player)
    local elems = flib_gui.add(player.gui.screen, {
        type = "frame",
        name = "RoboMap",
        direction = "vertical",
        style = "roboden_frame",
        visible = false,
        {
            type = "flow",
            style = "flib_titlebar_flow",
            drag_target = "RoboMap",
            { type = "label",        style = "frame_title",               caption = "RoboDensity",      ignored_by_interaction = true },
            { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
        },
        {
            name = "tabledisplay",
            type = "table",
            style = "slot_table",
            direction = "vertical",
            column_count = 1,
            {
                type = "label",
                caption = { "gui.roboden-label-selection" },
                tooltip = { "gui.roboden-tooltip-description" }
            },
            { type = "line"
            },
            {

                name = "mode",
                type = "drop-down",
                items = { "Logistic", "Construction", "Both" },
                selected_index = 1,
                handler = { [defines.events.on_gui_selection_state_changed] = gui.select_mode }
            },

            { type = "line"
            },
            {

                type = "button",
                name = "toggle_empty_alerts",
                caption = { "gui.roboden-caption-tag" },
                style = "button",
                handler = { [defines.events.on_gui_click] = gui.toggle_empty_tags },
                tooltip = { "gui.roboden-tag-description" },
                auto_toggle = true,
            }
        }

    })



    storage.guis[player.index] = {
        elems = elems,
        player = player,
        tags = {}
    }
end

function gui.toggle_empty_tags(self, e)
    local force = self.player.force
    if alerts then
        -- remove tags
        local tags = self.tags
        for _, tag in pairs(tags) do
            tag.destroy()
        end
        alerts = false
    else
        -- add tags
        for _, roboport in pairs(self.player.surface.find_entities_filtered({ name = "roboport" })) do
            local logistic_count = roboport.get_inventory(defines.inventory.roboport_robot).get_item_count(
                "logistic-robot")
            local construction_count = roboport.get_inventory(defines.inventory.roboport_robot).get_item_count(
                "construction-robot")
            if construction_count == 0 and logistic_count == 0 then
                table.insert(self.tags, force.add_chart_tag(self.player.surface, {
                    position = { roboport.position.x, roboport.position.y },
                    icon = {
                        type = "virtual",
                        name = "signal-skull",
                    },
                    text = "Empty"
                }))
            end
        end
        alerts = true
    end
end

function gui.select_mode(self, e)
    if e.element.selected_index == 1 then
        mode = "logistic"
    elseif e.element.selected_index == 2 then
        mode = "construction"
    elseif e.element.selected_index == 3 then
        mode = "both"
    end
    rendering.clear("RoboDensity")
    render_density_overlay(self.player)
end

function gui.show(self)
    self.elems.RoboMap.visible = true
end

function gui.hide(self)
    rendering.clear("RoboDensity")
    self.elems.RoboMap.visible = false
end

function gui.toggle_visible(self)
    if self.elems.RoboMap.visible then
        gui.hide(self)
        self.player.set_shortcut_toggled("roboden-toggle-gui", false)
    else
        gui.show(self)
        render_density_overlay(self.player)
        self.player.set_shortcut_toggled("roboden-toggle-gui", true)
    end
end

function gui.destroy(self)
    if self.window and self.window.valid then
        self.destroy()
    end

    self.elems = nil
end

flib_gui.add_handlers(gui, function(e, handler)
    local self = storage.guis[e.player_index]
    if self then
        handler(self, e)
    end
end)
flib_gui.handle_events()

script.on_init(function()
    storage.guis = {}
    for _, player in pairs(game.players) do
        gui.build(player)
    end
end)
script.on_event(defines.events.on_player_created, function(e)
    local player = game.get_player(e.player_index)
    gui.build(player)
end)

script.on_event(defines.events.on_player_removed, function(e)
    storage.guis[e.player_index] = nil
end)

script.on_event({ "roboden-toggle-gui", defines.events.on_lua_shortcut }, function(event)
    local self = storage.guis[event.player_index]
    gui.toggle_visible(self)
end)

function render_density_overlay(player)
    -- COLOR CODE
    -- NO BOTS AT ALL
    -- RED

    -- MODE LOGISTIC
    -- NO BOTS = RED
    -- HAS BOTS = GREEN OPACITY

    -- MODE CONSTRUCTION
    -- NO BOTS = RED
    -- HAS BOTS = GREEN OPACITY

    -- MODE BOTH
    -- NO BOTS = RED
    -- IDEAL = TEAL: 1:1
    -- MORE LOGIC THAN CONSTRUCTION = GREEN OPACITY
    -- MORE CONSTRUCTION THAN LOGIS = BLUE OPACITY
    local surface = player.surface
    local max_robots = 350
    local color = {}
    for _, roboport in pairs(surface.find_entities_filtered({ name = "roboport" })) do
        local logistic_count = roboport.get_inventory(defines.inventory.roboport_robot).get_item_count("logistic-robot")
        local construction_count = roboport.get_inventory(defines.inventory.roboport_robot).get_item_count(
            "construction-robot")


        if construction_count == 0 and logistic_count == 0 then
            color = { r = 1, g = 0, b = 0, a = 1 }
        end
        if mode == "logistic" then
            if logistic_count == 0 then
                color = { r = 1, g = 0, b = 0, a = 1 }
            else
                local opacity = math.min(math.max(logistic_count / max_robots, 0), 1)
                local adjG = math.max(0, math.min(1, (math.min(math.max(1, 0), 1) * opacity)))
                color = { r = 0, g = adjG, b = 0, a = opacity }
            end
        elseif mode == "construction" then
            if construction_count == 0 then
                color = { r = 1, g = 0, b = 0, a = 1 }
            else
                local opacity = math.min(math.max(construction_count / max_robots, 0), 1)
                local adjG = math.max(0, math.min(1, (math.min(math.max(1, 0), 1) * opacity)))
                color = { r = 0, g = adjG, b = 0, a = opacity }
            end
        elseif mode == "both" then
            if logistic_count == 0 or construction_count == 0 then
                color = { r = 1, g = 0, b = 0, a = 1 }
            else
                local opacity = math.min(math.max((logistic_count + construction_count) / (max_robots), 0), 1)
                local adjG = math.max(0,
                    math.min(1, math.min(math.max(logistic_count / construction_count, 0), 1) * opacity))
                local adjB = math.max(0,
                    math.min(1, math.min(math.max(1 / (logistic_count / construction_count), 0), 1) * opacity))
                color = { r = 0, g = adjG, b = adjB, a = opacity }
            end
        end
        draw_on_map(roboport, color, surface)
    end
end

function draw_on_map(roboport, color, surface)
    local roboport_area = 10
    rendering.draw_circle({
        color = color,
        filled = true,
        surface = surface,
        radius = roboport_area,
        target = { roboport.position.x, roboport.position.y },
        players = { player },
        visible = true,
        draw_on_ground = true
    })
end
