/*
* Copyright (c) 2019 Lains
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/
namespace Rakugaki {
    public class MainWindow : Hdy.Window {
        public Gtk.Application app { get; construct; }
        public Widgets.UI ui;
        public Hdy.HeaderBar titlebar;
        public Hdy.HeaderBar faux_titlebar;
        public Gtk.ActionBar actionbar;
        public Granite.ModeSwitch mode_switch;
        public Gtk.Grid grid;
        public Gtk.Grid sgrid;
        public Gtk.Box main_frame_grid;
        public Gtk.Separator separator;
        public Hdy.Leaflet leaflet;

        private int uid;
        private static int uid_counter = 0;

        // Global Color Palette
        public string background = "#F7F7F7";
        public string t_background = "#FFF";
        public string t_foreground = "#000";
        public string f_high = "#30292E";
        public string f_med = "#90898E";
        public string f_low = "#C0B9BEC";
        public string f_inv = "#30292E";
        public string b_high = "#30292E";
        public string b_med = "#80797E";
        public string b_low = "#AAAAAA";
        public string b_inv = "#FFB545";

        private const Gtk.TargetEntry [] targets = {{
            "text/uri-list", 0, 0
        }};

        public MainWindow (Gtk.Application application) {
            Hdy.init ();

            Object (
                application: application,
                app: application,
                icon_name: "com.github.lainsce.rakugaki",
                title: "Rakugaki",
                height_request: 585,
                width_request: 755
            );

            change_theme ();

            if (Rakugaki.Application.grsettings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
                change_theme ();
            }

            Rakugaki.Application.grsettings.notify["prefers-color-scheme"].connect (() => {
                change_theme ();
            });

            key_press_event.connect ((e) => {
                uint keycode = e.hardware_keycode;

                if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                    if (match_keycode (Gdk.Key.q, keycode)) {
                        this.destroy ();
                    }

                    if (match_keycode (Gdk.Key.z, keycode)) {
                        ui.undo ();
                        ui.current_path = new Path ();
				        ui.da.queue_draw ();
                    }
                }
                return false;
            });

            this.uid = uid_counter++;
        }

        construct {
            var settings = AppSettings.get_default ();
            int x = settings.window_x;
            int y = settings.window_y;
            if (x != -1 && y != -1) {
                this.move (x, y);
            }
            if (settings.window_maximize) {
                this.maximize ();
            } else {
                this.unmaximize ();
            }

            this.get_style_context ().add_class ("rounded");
            this.get_style_context ().add_class ("dm-window");

            weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
            default_theme.add_resource_path ("/com/github/lainsce/rakugaki");

            titlebar = new Hdy.HeaderBar ();
            titlebar.show_close_button = true;
            titlebar.has_subtitle = false;
            titlebar.title = "Rakugaki";
            var titlebar_style_context = titlebar.get_style_context ();
            titlebar_style_context.add_class (Gtk.STYLE_CLASS_FLAT);
            titlebar_style_context.add_class ("dm-toolbar");

            var new_button = new Gtk.Button ();
			new_button.has_tooltip = true;
			new_button.set_image (new Gtk.Image.from_icon_name ("document-new-symbolic", Gtk.IconSize.SMALL_TOOLBAR));
			new_button.tooltip_text = (_("New file"));

			titlebar.pack_start (new_button);

			var save_button = new Gtk.Button ();
			save_button.set_image (new Gtk.Image.from_icon_name ("document-save-symbolic", Gtk.IconSize.SMALL_TOOLBAR));
			save_button.has_tooltip = true;
			save_button.tooltip_text = (_("Save file"));

			titlebar.pack_start (save_button);

			var undo_button = new Gtk.Button ();
			undo_button.set_image (new Gtk.Image.from_icon_name ("edit-undo-symbolic", Gtk.IconSize.SMALL_TOOLBAR));
			undo_button.has_tooltip = true;
			undo_button.tooltip_text = (_("Undo Last Line"));

            titlebar.pack_start (undo_button);

            var see_grid_button = new Gtk.Button ();
			see_grid_button.set_image (new Gtk.Image.from_icon_name ("grid-dots-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			see_grid_button.has_tooltip = true;
			see_grid_button.tooltip_text = (_("Show/Hide Grid"));
            
            titlebar.pack_end (see_grid_button);

            faux_titlebar = new Hdy.HeaderBar ();
            faux_titlebar.show_close_button = true;
            faux_titlebar.has_subtitle = false;
            var faux_titlebar_style_context = faux_titlebar.get_style_context ();
            faux_titlebar_style_context.add_class (Gtk.STYLE_CLASS_FLAT);
            faux_titlebar_style_context.add_class ("dm-sidebar");

            var scrolled = new Gtk.ScrolledWindow (null, null);
            ui = new Widgets.UI (this);
            scrolled.add (ui);
            scrolled.expand = true;

            new_button.clicked.connect ((e) => {
				ui.clear ();
            });
            
            save_button.clicked.connect ((e) => {
				try {
					ui.save ();
				} catch (Error e) {
					warning ("Unexpected error during save: " + e.message);
				}
            });
            
            undo_button.clicked.connect ((e) => {
				ui.undo ();
				ui.current_path = new Path ();
				ui.da.queue_draw ();
            });

            see_grid_button.clicked.connect ((e) => {
				if (ui.see_grid == true) {
					ui.see_grid = false;
				} else if (ui.see_grid == false) {
					ui.see_grid = true;
				}
				ui.da.queue_draw ();
            });

            sgrid = new Gtk.Grid ();
            sgrid.get_style_context ().add_class ("dm-sidebar");
            sgrid.attach (faux_titlebar, 0, 0, 1, 1);
            sgrid.attach (ui.box, 0, 1, 1, 1);
            sgrid.show_all ();

            main_frame_grid = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            main_frame_grid.expand = true;
            main_frame_grid.add (scrolled);

            grid = new Gtk.Grid ();
            grid.attach (titlebar, 1, 0, 1, 1);
            grid.attach (main_frame_grid, 1, 1, 1, 1);
            grid.show_all ();

            separator = new Gtk.Separator (Gtk.Orientation.VERTICAL);
            var separator_cx = separator.get_style_context ();
            separator_cx.add_class ("vsep");

            leaflet = new Hdy.Leaflet () {
                transition_type = Hdy.LeafletTransitionType.UNDER,
                can_swipe_back = true
            };
            leaflet.add (sgrid);
            leaflet.add (separator);
            leaflet.add (grid);
            leaflet.set_visible_child (grid);
            leaflet.show_all ();

            update ();
            leaflet.notify["folded"].connect (() => {
                update ();
            });

            Gtk.drag_dest_set (this,Gtk.DestDefaults.ALL, targets, Gdk.DragAction.COPY);
            this.drag_data_received.connect(this.on_drag_data_received);
            this.add (leaflet);
            this.show_all ();
        }

        private void update () {
            if (leaflet != null && leaflet.get_folded ()) {
                // On Mobile size, so.... have to have no buttons anywhere.
                faux_titlebar.set_decoration_layout (":");
                titlebar.set_decoration_layout (":");
            } else {
                // Else you're on Desktop size, so business as usual.
                faux_titlebar.set_decoration_layout ("close:");
                titlebar.set_decoration_layout (":maximize");
            }
        }

        private void on_drag_data_received (Gdk.DragContext drag_context, int x, int y,
                                        Gtk.SelectionData data, uint info, uint time) {
            foreach(string uri in data.get_uris ()) {
                string file = uri.replace ("file://","").replace ("file:/","");
                file = Uri.unescape_string (file);
                print ("Got file!\n");
                get_colors_from_svg (file);
            }
            Gtk.drag_finish (drag_context, true, false, time);
        }

        public void get_colors_from_svg (string file) {
            string regString = "id='(?<id>.*)' fill='(?<color>#[A-Fa-f0-9]{6})\'";
            string input = "";
            try {
                GLib.FileUtils.get_contents (file, out input, null);
            } catch {}

            Regex regex;
            MatchInfo match;
            try {
                regex = new Regex (regString);
                if (regex.match (input, 0, out match)) {
                    do {
                        if (match.fetch_named ("id") == "background") {
                            string fbackground = match.fetch_named ("color");
                            this.background = fbackground;
                        } else if (match.fetch_named ("id") == "f_high") {
                            string ff_high = match.fetch_named ("color");
                            this.f_high = ff_high;
                        } else if (match.fetch_named ("id") == "f_med") {
                            string ff_med = match.fetch_named ("color");
                            this.f_med = ff_med;
                        } else if (match.fetch_named ("id") == "f_low") {
                            string ff_low = match.fetch_named ("color");
                            this.f_low = ff_low;
                        } else if (match.fetch_named ("id") == "f_inv") {
                            string ff_inv = match.fetch_named ("color");
                            this.f_inv = ff_inv;
                        } else if (match.fetch_named ("id") == "b_high") {
                            string fb_high = match.fetch_named ("color");
                            this.b_high = fb_high;
                        } else if (match.fetch_named ("id") == "b_med") {
                            string fb_med = match.fetch_named ("color");
                            this.b_med = fb_med;
                        } else if (match.fetch_named ("id") == "b_low") {
                            string fb_low = match.fetch_named ("color");
                            this.b_low = fb_low;
                        } else if (match.fetch_named ("id") == "b_inv") {
                            string fb_inv = match.fetch_named ("color");
                            this.b_inv = fb_inv;
                        }
                    } while (match.next ());
                    string css_light = """
                    @define-color colorPrimary %s;
                    @define-color colorSecondary %s;
                    @define-color colorAccent %s;
                    @define-color windowBackground %s;
                    @define-color windowPrimary %s;
                    @define-color textColorPrimary %s;
                    @define-color textColorSecondary %s;
                    @define-color iconColorPrimary %s;
                    @define-color titlePrimary %s;
                    @define-color titleSecondary %s;
    
                    window.unified {
                        border-radius: 8px;
                    }
    
                    .title {
                        font-weight: 700;
                        text-shadow: none;
                    }
    
                    .titlebutton image {
                        color: @titleSecondary;
                        -gtk-icon-shadow: none;
                    }
    
                    .dm-window {
                        background: @colorPrimary;
                        color: @windowPrimary;
                    }
    
                    .dm-toolbar {
                        background: @titlePrimary;
                        color: @titleSecondary;
                        box-shadow: none;
                        border: none;
                        border-bottom: 1px solid alpha(black, 0.25);
                    }
    
                    .dm-toolbar .image-button {
                        color: @titleSecondary;
                        -gtk-icon-shadow: none;
                    }

                    .dm-toolbar .image-button {
                        border-radius: 8px;
                    }
                    
                    .dm-toolbar .image-button image {
                        padding: 0 6px;
                    }
                    
                    .dm-toolbar .image-button:focus,
                    .dm-toolbar .image-button:hover {
                        background: shade(shade(mix (@colorSecondary, @colorPrimary, 0.85), 0.88), 0.95);
                    }
    
                    .dm-sidebar,
                    .dm-sidebar .dm-box,
                    .dm-sidebar titlebar {
                        background: mix (@colorSecondary, @colorPrimary, 0.85);
                        box-shadow: none;
                        border: none;
                        color: @iconColorPrimary;
                    }
    
                    .dm-tool {
                        border: 1px solid mix (@colorSecondary, @colorPrimary, 0.85);
                        margin-bottom: 6px;
                        border-radius: 8px;
                    }
    
                    .dm-tool:hover {
                        border: 1px solid shade(mix (@colorSecondary, @colorPrimary, 0.85), 0.88);
                    }
    
                    .dm-box image {
                        color: alpha (@textColorPrimary, 0.66);
                        -gtk-icon-shadow: none;
                    }
    
                    .dm-box button:not(.dm-tool):hover image {
                        color: @iconColorPrimary;
                    }
    
                    .dm-box button:not(.dm-tool):active image {
                        color: @iconColorPrimary;
                    }
    
                    .dm-reverse image {
                        -gtk-icon-transform: rotate(180deg);
                    }
    
                    .dm-grid {
                        background: @colorPrimary;
                    }
    
                    .dm-text {
                        font-family: 'Cousine', Courier, monospace;
                        font-size: 1.66em;
                        color: @textColorPrimary;
                    }
    
                    .dm-clrbtn {
                        background: mix (@colorSecondary, @colorPrimary, 0.85);
                        color: @textColorPrimary;
                        box-shadow: 0 1px transparent inset;
                        border: none;
                    }
    
                    .dm-clrbtn:active {
                        background: @colorAccent;
                    }
    
                    .dm-clrbtn colorswatch {
                        border-radius: 8px;
                    }
                    """.printf(this.background, this.b_inv, this.b_med, this.b_high, this.b_high, this.f_high, this.b_high, this.f_inv, this.b_low, this.b_inv);

                    try {
                        var provider = new Gtk.CssProvider ();
                        provider.load_from_data (css_light, -1);
                        Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),provider,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                    } catch {}

                    ui.line_color.parse (this.f_high);
                    ui.grid_main_dot_color.parse (this.b_med);
			        ui.grid_dot_color.parse (this.b_low);
			        ui.background_color.parse (this.background);
			        ui.line_color_button.rgba = ui.line_color;

                    print ("Setupped colors from file.\n");
                }
            } catch (Error error) {
                print (@"SVG File error: $(error.message)\n");
            }
        }

#if VALA_0_42
        protected bool match_keycode (uint keyval, uint code) {
#else
        protected bool match_keycode (int keyval, uint code) {
#endif
            Gdk.KeymapKey [] keys;
            Gdk.Keymap keymap = Gdk.Keymap.get_for_display (Gdk.Display.get_default ());
            if (keymap.get_entries_for_keyval (keyval, out keys)) {
                foreach (var key in keys) {
                    if (code == key.keycode)
                        return true;
                    }
                }

            return false;
        }

        public override bool delete_event (Gdk.EventAny event) {
            int x, y;
            get_position (out x, out y);

            var settings = AppSettings.get_default ();
            settings.window_x = x;
            settings.window_y = y;
            settings.window_maximize = is_maximized;

            if (ui.dirty) {
                try {
					ui.clear ();
				} catch (Error e) {
					warning ("Unexpected error during save: " + e.message);
				}
            }

            return false;
        }

        public void change_theme () {
            if (Rakugaki.Application.grsettings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK) {
                Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = true;
                t_background = "#000";
                t_foreground = "#FFF";
                background = "#181818";
                f_high = "#e9eef0";
                f_med = "#90898E";
                f_low = "#30393C";
                f_inv = "#e9eef0";
                b_high = "#e9eef0";
                b_med = "#80797E";
                b_low = "#333333";
                b_inv = "#FFB545";
                ui.line_color.parse (this.f_high);
                ui.grid_main_dot_color.parse (this.b_med);
                ui.grid_dot_color.parse (this.b_low);
                ui.background_color.parse (this.background);
                ui.line_color_button.rgba = ui.line_color;
                ui.da.queue_draw ();
                var provider = new Gtk.CssProvider ();
                string css_light = """
                    @define-color colorPrimary %s;
                    @define-color colorSecondary %s;
                    @define-color colorAccent %s;
                    @define-color windowBackground %s;
                    @define-color windowPrimary %s;
                    @define-color textColorPrimary %s;
                    @define-color textColorSecondary %s;
                    @define-color iconColorPrimary %s;
                    @define-color titlePrimary %s;
                    @define-color titleSecondary %s;
    
                    window.unified {
                        border-radius: 8px;
                    }
    
                    .title {
                        font-weight: 700;
                        text-shadow: none;
                    }
    
                    .titlebutton image {
                        color: @titleSecondary;
                        -gtk-icon-shadow: none;
                    }

                    .dm-toolbar .image-button {
                        border-radius: 8px;
                    }
                    
                    .dm-toolbar .image-button image {
                        padding: 0 6px;
                    }
                    
                    .dm-toolbar .image-button:focus,
                    .dm-toolbar .image-button:hover {
                        background: shade(@base_color, 0.95);
                    }
    
                    .dm-window {
                        background: @colorPrimary;
                        color: @windowPrimary;
                    }
    
                    .dm-toolbar {
                        background: @titlePrimary;
                        color: @titleSecondary;
                        box-shadow: none;
                        border: none;
                        border-bottom: 1px solid alpha(black, 0.25);
                    }
    
                    .dm-toolbar .image-button {
                        color: @titleSecondary;
                        -gtk-icon-shadow: none;
                    }
    
                    .dm-sidebar,
                    .dm-sidebar .dm-box,
                    .dm-sidebar titlebar {
                        background: mix (@colorSecondary, @colorPrimary, 0.85);
                        box-shadow: none;
                        border: none;
                        color: @iconColorPrimary;
                    }
    
                    .dm-tool {
                        border: 1px solid mix (@colorSecondary, @colorPrimary, 0.85);
                        margin-bottom: 6px;
                        border-radius: 8px;
                    }
    
                    .dm-tool:hover {
                        border: 1px solid shade(mix (@colorSecondary, @colorPrimary, 0.85), 1.2);
                    }
    
                    .dm-box image {
                        color: alpha (@textColorPrimary, 0.66);
                        -gtk-icon-shadow: none;
                    }
    
                    .dm-box button:not(.dm-tool):hover image {
                        color: @iconColorPrimary;
                    }
    
                    .dm-box button:not(.dm-tool):active image {
                        color: @iconColorPrimary;
                    }
    
                    .dm-reverse image {
                        -gtk-icon-transform: rotate(180deg);
                    }
    
                    .dm-grid {
                        background: @colorPrimary;
                    }
    
                    .dm-text {
                        font-family: 'Cousine', Courier, monospace;
                        font-size: 1.66em;
                        color: @textColorPrimary;
                    }
    
                    .dm-clrbtn {
                        background: mix (@colorSecondary, @colorPrimary, 0.85);
                        color: @textColorPrimary;
                        box-shadow: 0 1px transparent inset;
                        border: none;
                    }
    
                    .dm-clrbtn:active {
                        background: @colorAccent;
                    }
    
                    .dm-clrbtn colorswatch {
                        border-radius: 8px;
                    }
                    """.printf(this.background, this.b_inv, this.b_med, this.b_inv, this.b_high, this.f_high, this.b_high, this.f_inv, this.t_background, this.t_foreground);
                try {
                    provider.load_from_data (css_light, -1);
                    Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),provider,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                } catch {}
            } else if (Rakugaki.Application.grsettings.prefers_color_scheme == Granite.Settings.ColorScheme.NO_PREFERENCE) {
                Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = false;
                t_background = "#FFF";
                t_foreground = "#000";
                background = "#F7F7F7";
                f_high = "#30292E";
                f_med = "#90898E";
                f_low = "#C0B9BEC";
                f_inv = "#30292E";
                b_high = "#30292E";
                b_med = "#80797E";
                b_low = "#AAAAAA";
                b_inv = "#FFB545";
                ui.line_color.parse (this.f_high);
                ui.grid_main_dot_color.parse (this.b_med);
                ui.grid_dot_color.parse (this.b_low);
                ui.background_color.parse (this.background);
                ui.line_color_button.rgba = ui.line_color;
                ui.da.queue_draw ();
                var provider = new Gtk.CssProvider ();
                string css_light = """
                    @define-color colorPrimary %s;
                    @define-color colorSecondary %s;
                    @define-color colorAccent %s;
                    @define-color windowBackground %s;
                    @define-color windowPrimary %s;
                    @define-color textColorPrimary %s;
                    @define-color textColorSecondary %s;
                    @define-color iconColorPrimary %s;
                    @define-color titlePrimary %s;
                    @define-color titleSecondary %s;
    
                    window.unified {
                        border-radius: 8px;
                    }
    
                    .title {
                        font-weight: 700;
                        text-shadow: none;
                    }
    
                    .titlebutton image {
                        color: @titleSecondary;
                        -gtk-icon-shadow: none;
                    }
    
                    .dm-window {
                        background: @colorPrimary;
                        color: @windowPrimary;
                    }
    
                    .dm-toolbar {
                        background: @titlePrimary;
                        color: @titleSecondary;
                        box-shadow: none;
                        border: none;
                        border-bottom: 1px solid alpha(black, 0.25);
                    }
    
                    .dm-toolbar .image-button {
                        color: @titleSecondary;
                        -gtk-icon-shadow: none;
                    }

                    .dm-toolbar .image-button {
                        border-radius: 8px;
                    }
                    
                    .dm-toolbar .image-button image {
                        padding: 0 6px;
                    }
                    
                    .dm-toolbar .image-button:focus,
                    .dm-toolbar .image-button:hover {
                        background: shade(@base_color, 0.95);
                    }
    
                    .dm-sidebar,
                    .dm-sidebar .dm-box,
                    .dm-sidebar titlebar {
                        background: mix (@colorSecondary, @colorPrimary, 0.85);
                        box-shadow: none;
                        border: none;
                        color: @iconColorPrimary;
                    }
    
                    .dm-tool {
                        border: 1px solid mix (@colorSecondary, @colorPrimary, 0.85);
                        margin-bottom: 6px;
                        border-radius: 8px;
                    }
    
                    .dm-tool:hover {
                        border: 1px solid shade(mix (@colorSecondary, @colorPrimary, 0.85), 0.88);
                    }
    
                    .dm-box image {
                        color: alpha (@textColorPrimary, 0.66);
                        -gtk-icon-shadow: none;
                    }
    
                    .dm-box button:not(.dm-tool):hover image {
                        color: @iconColorPrimary;
                    }
    
                    .dm-box button:not(.dm-tool):active image {
                        color: @iconColorPrimary;
                    }
    
                    .dm-reverse image {
                        -gtk-icon-transform: rotate(180deg);
                    }
    
                    .dm-grid {
                        background: @colorPrimary;
                    }
    
                    .dm-text {
                        font-family: 'Cousine', Courier, monospace;
                        font-size: 1.66em;
                        color: @textColorPrimary;
                    }
    
                    .dm-clrbtn {
                        background: mix (@colorSecondary, @colorPrimary, 0.85);
                        color: @textColorPrimary;
                        box-shadow: 0 1px transparent inset;
                        border: none;
                    }
    
                    .dm-clrbtn:active {
                        background: @colorAccent;
                    }
    
                    .dm-clrbtn colorswatch {
                        border-radius: 8px;
                    }
                    """.printf(this.background, this.b_inv, this.b_med, this.b_inv, this.b_high, this.f_high, this.b_high, this.f_inv, this.t_background, this.t_foreground);
                try {
                    provider.load_from_data (css_light, -1);
                    Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (),provider,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                } catch {}
            }
        }
    }
}
