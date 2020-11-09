namespace Rakugaki {
	public class Point {
		public double x;
		public double y;
		public Point (double x, double y) {
			this.x = Math.fabs(x);
			this.y = Math.fabs(y);
		}
	}

	public class Path {
		public List<Point> points = null;
		public bool is_dotter {get; set; default=false;}
		public bool is_halftone {get; set; default=false;}
		public bool is_eraser {get; set; default=false;}
	}

	public class DrawingArea : Gtk.DrawingArea {
		public signal void stroke_added (double[] coordinates);
		public signal void stroke_removed (uint n_strokes);
	}

	public class Widgets.UI : Gtk.VBox {
		public MainWindow win;
		public signal void stroke_added (double[] coordinates);
		public signal void stroke_removed (uint n_strokes);
		public DrawingArea da;
		public EditableLabel line_thickness_label;
		public Gtk.ColorButton line_color_button;
		public Gtk.Grid box;

		public List<Path> paths = new List<Path> ();
		public Path current_path = null;

		private int ratio = 25;
		public int line_thickness = 5;

		public Gdk.RGBA line_color;
		public Gdk.RGBA grid_main_dot_color;
		public Gdk.RGBA grid_dot_color;
		public Gdk.RGBA background_color;

		public bool dirty {get; set;}
		public bool see_grid {get; set; default=false;}
		public bool halftone {get; set; default=false;}
		public bool dotter {get; set; default=false;}
		public bool eraser {get; set; default=false;}

		public UI (MainWindow win) {
			this.win = win;

			da = new DrawingArea ();

			da.add_events (Gdk.EventMask.BUTTON_PRESS_MASK |
						   Gdk.EventMask.BUTTON_RELEASE_MASK |
						   Gdk.EventMask.BUTTON_MOTION_MASK);

			da.button_press_event.connect ((e) => {
				if (halftone) {
					current_path = new Path ();
					current_path.is_halftone = true;
					current_path.points.append (new Point (e.x, e.y));
					paths.append (current_path);
				}
				if (dotter) {
					current_path = new Path ();
					current_path.is_dotter = true;
					current_path.points.append (new Point (e.x, e.y));
					paths.append (current_path);
				}
				if (eraser) {
					current_path = new Path ();
					current_path.is_eraser = true;
					current_path.points.append (new Point (e.x, e.y));
					paths.append (current_path);
				}
				if (!halftone && !dotter && !eraser) {
					current_path = new Path ();
					current_path.is_halftone = false;
					current_path.is_dotter = false;
					current_path.is_eraser = false;
					current_path.points.append (new Point (e.x, e.y));
					paths.append (current_path);
				}
				dirty = true;
				return false;
			});

			da.button_release_event.connect ((e) => {
				Gtk.Allocation allocation;
				get_allocation (out allocation);

				double x = e.x.clamp ((double) allocation.x,
									  (double) (allocation.x + allocation.width));
				double y = e.y.clamp ((double) allocation.y,
									  (double) (allocation.y + allocation.height));
				current_path.points.append (new Point (x, y));

				da.queue_draw ();

				current_path = null;

				return false;
			});

			da.motion_notify_event.connect ((e) => {
				Gtk.Allocation allocation;
				get_allocation (out allocation);

				double x = e.x.clamp ((double) allocation.x,
									  (double) (allocation.x + allocation.width));
				double y = e.y.clamp ((double) allocation.y,
									  (double) (allocation.y + allocation.height));
				Point last = current_path.points.last ().data;
				double dx = Math.fabs(last.x - x);
				double dy = Math.fabs(last.y - y);

				// Thanks Neauoire! =)
				double err = dx + dy;
				double e2 = 2 * err;
				if (e2 >= dy) {
					err += dy; x += (x < last.x ? 1 : -1);
					current_path.points.append (new Point (x, y));
				}
      			if (e2 <= dx) {
					err += dx; y += (y < last.y ? 1 : -1);
					current_path.points.append (new Point (x, y));
				}
				//

				da.queue_draw ();

				return false;
			});

			da.draw.connect ((c) => {
				main_draw (c);
				return false;
			});

			box = new Gtk.Grid ();
			box.orientation = Gtk.Orientation.VERTICAL;
			box.margin = 12;
			box.vexpand = true;
			box.set_size_request (90,-1);
			box.get_style_context ().add_class ("dm-box");

			line_color_button = new Gtk.ColorButton ();
			line_color_button.height_request = 24;
			line_color_button.width_request = 24;
			line_color_button.show_editor = true;
			line_color_button.get_style_context ().add_class ("dm-clrbtn");
			line_color_button.get_style_context ().remove_class ("color");
			line_color_button.tooltip_text = (_("Line Color"));

			line_color_button.color_set.connect ((e) => {
				line_color = line_color_button.rgba;
				da.queue_draw ();
			});

			var line_thickness_button = new Gtk.Button ();
			line_thickness_button.set_image (new Gtk.Image.from_icon_name ("line-thickness-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			line_thickness_button.has_tooltip = true;
			line_thickness_button.tooltip_text = (_("Change Line Thickness"));
			line_thickness_label = new EditableLabel (line_thickness.to_string());
			line_thickness_label.get_style_context ().add_class ("dm-text");
			line_thickness_label.valign = Gtk.Align.CENTER;
			line_thickness_label.hexpand = false;
			line_thickness_label.margin_top = 3;

			line_thickness_button.clicked.connect ((e) => {
				if (line_thickness < 50) {
					line_thickness++;
					line_thickness_label.text = line_thickness.to_string ();
					da.queue_draw ();
				} else {
					line_thickness = 1;
					line_thickness_label.text = line_thickness.to_string ();
					da.queue_draw ();
				}
			});

			line_thickness_label.changed.connect (() => {
				if (int.parse(line_thickness_label.title.get_label ()) > 50 || int.parse(line_thickness_label.title.get_label ()) < 1) {
					line_thickness = 1;
					line_thickness_label.text = line_thickness.to_string ();
					da.queue_draw ();
				} else {
					line_thickness = int.parse(line_thickness_label.title.get_label ());
					line_thickness_label.text = line_thickness.to_string ();
					da.queue_draw ();
				}
			});

			var line_thickness_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
			line_thickness_box.pack_start (line_thickness_button);
			line_thickness_box.pack_start (line_thickness_label);

			var normal_button = new Gtk.Button ();
            normal_button.set_image (new Gtk.Image.from_icon_name ("line-cap-normal-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			normal_button.has_tooltip = true;
			normal_button.always_show_image = true;
			normal_button.tooltip_text = (_("Pen"));
			normal_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
			normal_button.get_style_context ().add_class ("dm-tool");

			normal_button.clicked.connect ((e) => {
				eraser = false;
				halftone = false;
				dotter = false;
            });

			var halftone_button = new Gtk.Button ();
            halftone_button.set_image (new Gtk.Image.from_icon_name ("line-cap-halftone-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			halftone_button.has_tooltip = true;
			halftone_button.always_show_image = true;
			halftone_button.tooltip_text = (_("Halftoner"));
			halftone_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
			halftone_button.get_style_context ().add_class ("dm-tool");

			halftone_button.clicked.connect ((e) => {
				halftone = true;
				dotter = false;
				eraser = false;
			});
			
			var dotter_button = new Gtk.Button ();
            dotter_button.set_image (new Gtk.Image.from_icon_name ("line-cap-dotter-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			dotter_button.has_tooltip = true;
			dotter_button.always_show_image = true;
			dotter_button.tooltip_text = (_("Dotter"));
			dotter_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
			dotter_button.get_style_context ().add_class ("dm-tool");

			dotter_button.clicked.connect ((e) => {
				dotter = true;
				halftone = false;
				eraser = false;
            });

			var eraser_button = new Gtk.Button ();
            eraser_button.set_image (new Gtk.Image.from_icon_name ("eraser-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			eraser_button.has_tooltip = true;
			eraser_button.always_show_image = true;
			eraser_button.tooltip_text = (_("Eraser"));
			eraser_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
			eraser_button.get_style_context ().add_class ("dm-tool");

			eraser_button.clicked.connect ((e) => {
				eraser = true;
				dotter = false;
				halftone = false;
            });

			var separator = new Gtk.Grid ();
			separator.vexpand = true;

			box.attach (normal_button, 0, 0, 1, 1);
			box.attach (halftone_button, 0, 1, 1, 1);
			box.attach (dotter_button, 0, 2, 1, 1);
			box.attach (eraser_button, 0, 3, 1, 1);
			box.attach (separator, 0, 4, 1, 1);
			box.attach (line_color_button, 0, 5, 1, 1);
			box.attach (line_thickness_box, 0, 6, 1, 1);

			this.pack_start (da, true, true, 0);
			this.get_style_context ().add_class ("dm-grid");
			show_all ();

			da.stroke_added.connect ((coordinates) => {
					stroke_added (coordinates);
				});
			da.stroke_removed.connect ((n_strokes) => {
					stroke_removed (n_strokes);
				});
		}

		public void main_draw (Cairo.Context cr) {
			Gtk.Allocation allocation;
			get_allocation (out allocation);
			Cairo.ImageSurface sf2 = new Cairo.ImageSurface (Cairo.Format.ARGB32, allocation.width, allocation.height);
			Cairo.Context cr2 = new Cairo.Context (sf2);
			Cairo.ImageSurface sf3 = new Cairo.ImageSurface (Cairo.Format.ARGB32, allocation.width, allocation.height);
			Cairo.Context cr3 = new Cairo.Context (sf3);
			cr.set_source_surface (cr2.get_target (), 0, 0);
			draws (cr2);
			cr.rectangle (0, 0, allocation.width, allocation.height);
			cr.paint ();
			cr.set_source_surface (cr3.get_target (), 0, 0);
			draw_grid (cr3);
			cr.rectangle (0, 0, allocation.width, allocation.height);
			cr.paint ();
		}

		public void draws (Cairo.Context cr) {
			cr.set_source_rgba (background_color.red, background_color.green, background_color.blue, 1);
        	cr.paint ();
			cr.set_antialias (Cairo.Antialias.NONE);
			cr.set_fill_rule (Cairo.FillRule.EVEN_ODD);
			cr.set_line_cap (Cairo.LineCap.ROUND);
			cr.set_line_join (Cairo.LineJoin.ROUND);
			Cairo.ImageSurface p_ht = halftone_pattern ();
			Cairo.ImageSurface p_dt = dotter_pattern ();
			foreach (var path in paths) {
				if (path.is_halftone) {
					cr.set_line_width (1);
					cr.set_source_rgba (line_color.red, line_color.green, line_color.blue, 1);
					for (int i = 0; i < path.points.length (); i++) {
						int x = (int) Math.round(Math.floor(path.points.nth_data(i).x - (line_thickness / 2)) / 10) * 10;
						int y = (int) Math.round(Math.floor(path.points.nth_data(i).y - (line_thickness / 2)) / 12) * 12;
						cr.mask_surface (p_ht, x, y);
					}
				}
				if (path.is_dotter) {
					cr.set_line_width (1);
					cr.set_source_rgba (line_color.red, line_color.green, line_color.blue, 1);
					for (int i = 0; i < path.points.length (); i++) {
						int x = (int) Math.round(Math.floor(path.points.nth_data(i).x - (line_thickness / 2)) / 11) * 11;
						int y = (int) Math.round(Math.floor(path.points.nth_data(i).y - (line_thickness / 2)) / 11) * 11;
						cr.mask_surface (p_dt, x, y);
					}
				}
				if (path.is_eraser) {
					Gdk.cairo_set_source_rgba (cr, background_color);
					cr.set_line_width (9);
					Point first = path.points.first ().data;
					cr.move_to (first.x, first.y);
					for (int i = 0; i < path.points.length (); i++) {
						cr.line_to (path.points.nth_data(i).x, path.points.nth_data(i).y);
					}
					cr.stroke ();
				}
				if (!path.is_eraser && !path.is_halftone && !path.is_dotter) {
					Gdk.cairo_set_source_rgba (cr, line_color);
					cr.set_line_width (line_thickness);
					Point first = path.points.first ().data;
					cr.move_to (first.x, first.y);
					for (int i = 0; i < path.points.length (); i++) {
						cr.line_to (path.points.nth_data(i).x, path.points.nth_data(i).y);
					}
					cr.stroke ();
				}
			}
		}

		private void draw_grid (Cairo.Context cr) {
			cr.set_antialias (Cairo.Antialias.SUBPIXEL);
			cr.set_line_width (1);
			cr.set_fill_rule (Cairo.FillRule.EVEN_ODD);
			cr.set_line_cap (Cairo.LineCap.ROUND);
			cr.set_line_join (Cairo.LineJoin.ROUND);
			if (see_grid == true) {
				int i, j;
				int h = this.get_allocated_height ();
				int w = this.get_allocated_width ();

				for (i = 0; i <= w / ratio; i++) {
					for (j = 0; j <= h / ratio; j++) {
						if (i % 4 == 0 && j % 4 == 0) {
							cr.set_source_rgba (grid_main_dot_color.red, grid_main_dot_color.green, grid_main_dot_color.blue, 1);
							cr.arc ((i+1)*ratio, (j+1)*ratio, 1.5, 0, 2*Math.PI);
							cr.fill ();
						} else {
							cr.set_source_rgba (grid_dot_color.red, grid_dot_color.green, grid_dot_color.blue, 1);
							cr.arc ((i+1)*ratio, (j+1)*ratio, 1.0, 0, 2*Math.PI);
							cr.fill ();
						}
					}
				}
			}
		}

		private Cairo.ImageSurface halftone_pattern () {
			Cairo.ImageSurface p = new Cairo.ImageSurface (Cairo.Format.ARGB32, 9, 12);
			Cairo.Context p_cr = new Cairo.Context (p);
			int x, y;
			for (x = 0; x <= 9; x++) {
				for (y = 0; y <= 12; y++) {
					if ((x % 3 == 0 && y % 6 == 0) || (x % 3 == 2 && y % 6 == 3)) {
						p_cr.close_path ();
						p_cr.set_source_rgba (line_color.red, line_color.green, line_color.blue, 1);
						p_cr.rectangle (x, y, 1, 1);
						p_cr.fill ();
						p_cr.stroke ();
					} else {
						p_cr.close_path ();
						p_cr.set_source_rgba (background_color.red, background_color.green, background_color.blue, 0);
						p_cr.rectangle (x, y, 1, 1);
						p_cr.fill ();
						p_cr.stroke ();
					}
				}
			}
			Cairo.Pattern pn = new Cairo.Pattern.for_surface (p);
			pn.set_extend (Cairo.Extend.REPEAT);
			return p;
		}

		private Cairo.ImageSurface dotter_pattern () {
			Cairo.ImageSurface p = new Cairo.ImageSurface (Cairo.Format.ARGB32, 10, 10);
			Cairo.Context p_cr = new Cairo.Context (p);
			int i, j;
			for (i = 0; i <= 10; i++) {
				for (j = 0; j <= 10; j++) {
					if ((i % Math.floor(ratio/2) == 0 && j % Math.floor(ratio/2) == 0) ||
						(i % Math.floor(ratio/2) == 6 && j % Math.floor(ratio/2) == 6)) {
						p_cr.new_path ();
						p_cr.set_source_rgba (line_color.red, line_color.green, line_color.blue, 1);
						p_cr.rectangle (i, j, 1, 1);
						p_cr.fill ();
						p_cr.stroke ();
					} else {
						p_cr.new_path ();
						p_cr.set_source_rgba (background_color.red, background_color.green, background_color.blue, 0);
						p_cr.rectangle (i, j, 1, 1);
						p_cr.fill ();
						p_cr.stroke ();
					}
				}
			}
			Cairo.Pattern pn = new Cairo.Pattern.for_surface (p);
			pn.set_extend (Cairo.Extend.REPEAT);
			return p;
		}

		// IO Section
		public void clear () {
			var dialog = new Dialog ();
			dialog.transient_for = win;

			dialog.response.connect ((response_id) => {
				switch (response_id) {
					case Gtk.ResponseType.OK:
						debug ("User saves the file.");
						try {
							save ();
						} catch (Error e) {
							warning ("Unexpected error during save: " + e.message);
						}
						paths = null;
						current_path = new Path ();
						da.queue_draw ();
						dirty = false;
						stroke_removed (0);
						dialog.close ();
						break;
					case Gtk.ResponseType.NO:
						paths = null;
						current_path = new Path ();
						da.queue_draw ();
						stroke_removed (0);
						dialog.close ();
						break;
					case Gtk.ResponseType.CANCEL:
					case Gtk.ResponseType.CLOSE:
					case Gtk.ResponseType.DELETE_EVENT:
						dialog.close ();
						return;
					default:
						assert_not_reached ();
				}
			});


			if (dirty == true) {
				dialog.run ();
			}
		}

		public void undo () {
			if (paths != null) {
				unowned List<Path> last = paths.last ();
				unowned List<Path> prev = last.prev;
				paths.delete_link (last);
				if (current_path != null) {
					if (prev != null)
					current_path = prev.data;
					else
					current_path = null;
				}
				da.queue_draw ();
			}
		}

		public void save () throws Error {
			debug ("Save as button pressed.");
			var file = display_save_dialog ();

			string path = file.get_path ();

			if (file == null) {
				debug ("User cancelled operation. Aborting.");
			} else {
				Gtk.Allocation allocation;
				get_allocation (out allocation);
				var png = new Cairo.ImageSurface (Cairo.Format.ARGB32, da.get_allocated_width(),da.get_allocated_height());
				Cairo.Context c = new Cairo.Context (png);
				Gdk.RGBA background = Gdk.RGBA () {
					red = background_color.red, green = background_color.green, blue = background_color.blue, alpha = background_color.alpha
				};
				Gdk.cairo_set_source_rgba (c, background);
				c.paint ();
				Cairo.ImageSurface sf2 = new Cairo.ImageSurface (Cairo.Format.ARGB32, allocation.width, allocation.height);
				Cairo.Context cr2 = new Cairo.Context (sf2);
				Gdk.cairo_set_source_rgba (cr2, line_color);
				draws (cr2);

				c.set_source_surface (cr2.get_target (), 0, 0);
				c.rectangle (0, 0, allocation.width, allocation.height);
				c.paint ();
				png.write_to_png (path + ".png");
				file = null;
			}
		}

		public Gtk.FileChooserDialog create_file_chooser (string title,
		Gtk.FileChooserAction action) {
			var chooser = new Gtk.FileChooserDialog (title, null, action);
			chooser.add_button ("_Cancel", Gtk.ResponseType.CANCEL);
			if (action == Gtk.FileChooserAction.OPEN) {
				chooser.add_button ("_Open", Gtk.ResponseType.ACCEPT);
			} else if (action == Gtk.FileChooserAction.SAVE) {
				chooser.add_button ("_Save", Gtk.ResponseType.ACCEPT);
				chooser.set_do_overwrite_confirmation (true);
			}
			var filter1 = new Gtk.FileFilter ();
			filter1.set_filter_name (_("PNG files"));
			filter1.add_pattern ("*.png");
			chooser.add_filter (filter1);

			var filter = new Gtk.FileFilter ();
			filter.set_filter_name (_("All files"));
			filter.add_pattern ("*");
			chooser.add_filter (filter);
			return chooser;
		}

		public File display_save_dialog () {
			var chooser = create_file_chooser (_("Save file"),
			Gtk.FileChooserAction.SAVE);
			File file = null;
			if (chooser.run () == Gtk.ResponseType.ACCEPT)
			file = chooser.get_file ();
			chooser.destroy();
			return file;
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
	}
	public class Dialog : Granite.MessageDialog {
		public MainWindow win;
		public Dialog () {
			Object (
			image_icon: new ThemedIcon ("dialog-information"),
			primary_text: _("Save Image?"),
			secondary_text: _("There are unsaved changes to the image. If you don't save, changes will be lost forever.")
			);
		}
		construct {
			var cws = add_button (_("Close Without Saving"), Gtk.ResponseType.NO);
			cws.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
			var cancel = add_button (_("Cancel"), Gtk.ResponseType.CANCEL) as Gtk.Button;
			var save = add_button (_("Save"), Gtk.ResponseType.OK);
			save.has_focus = true;
			cancel.clicked.connect (() => { destroy (); });
		}
	}
}
