namespace Rakugaki {
	public class Point {
		public double x;
		public double y;
		public Point (double x, double y) {
			this.x = x;
			this.y = y;
		}
	}

	public class Path {
		public List<Point> points = null;
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

		public List<Path> paths = new List<Path> ();
		public Path current_path = null;

		private int ratio = 25;
		public int line_thickness = 1;

		public Gdk.RGBA line_color;
		public Gdk.RGBA grid_main_dot_color;
		public Gdk.RGBA grid_dot_color;
		public Gdk.RGBA background_color;

		public bool dirty {get; set;}
		public bool see_grid {get; set; default=true;}
		public bool halftone {get; set; default=false;}
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
				if (eraser) {
					current_path = new Path ();
					current_path.is_eraser = true;
					current_path.points.append (new Point (e.x, e.y));
					paths.append (current_path);
				}
				if (!halftone && !eraser) {
					current_path = new Path ();
					current_path.is_halftone = false;
					current_path.points.append (new Point (e.x, e.y));
					paths.append (current_path);
				}
				dirty = true;
				return false;
			});
	
			da.button_release_event.connect ((e) => {
				Gtk.Allocation allocation;
				get_allocation (out allocation);
				double[] coordinates = new double[current_path.points.length () * 2];
				int i = 0;
				foreach (var point in current_path.points) {
					coordinates[i] = point.x / (double)allocation.width;
					coordinates[i + 1] = point.y / (double)allocation.height;
				}
				stroke_added (coordinates);
	
				current_path = null;

				return false;
			});
	
			da.motion_notify_event.connect ((e) => {
				Gtk.Allocation allocation;
				get_allocation (out allocation);
	
				double x = e.x.clamp ((double)allocation.x,
										  (double)(allocation.x + allocation.width));
				double y = e.y.clamp ((double)allocation.y,
										  (double)(allocation.y + allocation.height));
				Point last = current_path.points.last ().data;
				double dx = Math.fabs(last.x - x);
				double dy = Math.fabs(last.y - y);
				if (Math.sqrt (dx * dx + dy * dy) > 5.0) {
					current_path.points.append (new Point (x, y));
					da.queue_draw ();
				}
				return false;
			});
	
			da.draw.connect ((c) => {
				main_draw (c);
				return false;
			});

			var actionbar = new Gtk.ActionBar ();
			actionbar.get_style_context ().add_class ("dm-actionbar");
			
			var new_button = new Gtk.Button ();
			new_button.has_tooltip = true;
			new_button.set_image (new Gtk.Image.from_icon_name ("document-new-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			new_button.tooltip_text = (_("New file"));
			
			new_button.clicked.connect ((e) => {
				clear ();
			});
			
			actionbar.pack_start (new_button);
			
			var save_button = new Gtk.Button ();
			save_button.set_image (new Gtk.Image.from_icon_name ("document-save-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			save_button.has_tooltip = true;
			save_button.tooltip_text = (_("Save file"));
			
			save_button.clicked.connect ((e) => {
				try {
					save ();
				} catch (Error e) {
					warning ("Unexpected error during save: " + e.message);
				}
			});
			
			actionbar.pack_start (save_button);
			
			var undo_button = new Gtk.Button ();
			undo_button.set_image (new Gtk.Image.from_icon_name ("edit-undo-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			undo_button.has_tooltip = true;
			undo_button.tooltip_text = (_("Undo Last Line"));
			
			undo_button.clicked.connect ((e) => {
				undo ();
				current_path = new Path ();
				da.queue_draw ();
			});
			
			actionbar.pack_start (undo_button);
			
			line_color_button = new Gtk.ColorButton ();
			line_color_button.margin_start = 6;
			line_color_button.height_request = 24;
			line_color_button.width_request = 24;
			line_color_button.show_editor = true;
			line_color_button.get_style_context ().add_class ("dm-clrbtn");
			line_color_button.get_style_context ().remove_class ("color");
			line_color_button.tooltip_text = (_("Line Color"));
			actionbar.pack_start (line_color_button);
			
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
			
			var line_thickness_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
			line_thickness_box.pack_start (line_thickness_button);
			line_thickness_box.pack_start (line_thickness_label);
			
			actionbar.pack_start (line_thickness_box);
			
			var halftone_button = new Gtk.Button ();
            halftone_button.set_image (new Gtk.Image.from_icon_name ("line-cap-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			halftone_button.has_tooltip = true;
			halftone_button.tooltip_text = (_("Change Pen Type"));

			halftone_button.clicked.connect ((e) => {
				eraser = false;
				if (halftone) {
					halftone = false;
				} else {
					halftone = true;
				}
            });

			actionbar.pack_end (halftone_button);
			
			var eraser_button = new Gtk.Button ();
            eraser_button.set_image (new Gtk.Image.from_icon_name ("eraser-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			eraser_button.has_tooltip = true;
			eraser_button.tooltip_text = (_("Eraser"));

			eraser_button.clicked.connect ((e) => {
				halftone = false;
				if (eraser) {
					eraser = false;
				} else {
					eraser = true;
				}
            });

            actionbar.pack_end (eraser_button);
			
			var see_grid_button = new Gtk.Button ();
			see_grid_button.set_image (new Gtk.Image.from_icon_name ("grid-dots-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
			see_grid_button.has_tooltip = true;
			see_grid_button.tooltip_text = (_("Show/Hide Grid"));
			
			see_grid_button.clicked.connect ((e) => {
				if (see_grid == true) {
					see_grid = false;
				} else if (see_grid == false) {
					see_grid = true;
				}
				da.queue_draw ();
			});
			
			actionbar.pack_end (see_grid_button);
			
			this.pack_end (actionbar, false, false, 0);
			this.pack_start (da, true, true, 0);
			this.get_style_context ().add_class ("dm-grid");
			this.margin = 1;
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
			draws (cr2);

			Cairo.ImageSurface sf3 = new Cairo.ImageSurface (Cairo.Format.ARGB32, allocation.width, allocation.height);
			Cairo.Context cr3 = new Cairo.Context (sf3);
			draw_grid (cr3);

			cr.set_source_surface (cr2.get_target (), 0, 0);
			cr.rectangle (0, 0, allocation.width, allocation.height);
			cr.paint ();
			cr.set_source_surface (cr3.get_target (), 0, 0);
			cr.rectangle (0, 0, allocation.width, allocation.height);
			cr.paint ();
		}

		public void draws (Cairo.Context cr) {
			cr.set_antialias (Cairo.Antialias.SUBPIXEL);
			cr.set_fill_rule (Cairo.FillRule.EVEN_ODD);
			cr.set_line_cap (Cairo.LineCap.ROUND);
			cr.set_line_join (Cairo.LineJoin.ROUND);
			foreach (var path in paths) {
				if (path.is_halftone) {
					Gdk.cairo_set_source_rgba (cr, line_color);
					cr.set_line_width (9);
					foreach (var point in path.points.next) {
						cr.rectangle (point.x, point.y, 1, 1);
						cr.fill ();
						cr.rectangle (point.x, point.y + 3, 1.5, 1.5);
						cr.fill ();
						cr.rectangle (point.x, point.y + 6, 1, 1);
						cr.fill ();
						cr.rectangle (point.x + 3, point.y, 1.5, 1.5);
						cr.fill ();
						cr.rectangle (point.x + 3, point.y + 3, 1.5, 1.5);
						cr.fill ();
						cr.rectangle (point.x + 3, point.y + 6, 1.5, 1.5);
						cr.fill ();
						cr.rectangle (point.x + 6, point.y, 1, 1);
						cr.fill ();
						cr.rectangle (point.x + 6, point.y + 3, 1.5, 1.5);
						cr.fill ();
						cr.rectangle (point.x + 6, point.y + 6, 1, 1);
						cr.fill ();
					}
					cr.stroke ();
				}
				if (path.is_eraser) {
					Gdk.cairo_set_source_rgba (cr, background_color);
					cr.set_line_width (9);
					Point first = path.points.first ().data;
					cr.move_to (first.x, first.y);
					foreach (var point in path.points.next) {
						cr.line_to (point.x, point.y);
					}
					cr.stroke ();
				}
				if (!path.is_eraser && !path.is_halftone) {
					Gdk.cairo_set_source_rgba (cr, line_color);
					cr.set_line_width (line_thickness);
					Point first = path.points.first ().data;
					cr.move_to (first.x, first.y);
					foreach (var point in path.points.next) {
						cr.line_to (point.x, point.y);
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
							cr.arc ((i+1)*ratio, (j+1)*ratio, 1.4, 0, 2*Math.PI);
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

		// IO Section
		private void clear () {
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
			var save = add_button (_("Save"), Gtk.ResponseType.OK);
			var cws = add_button (_("Close Without Saving"), Gtk.ResponseType.NO);
			var cancel = add_button (_("Cancel"), Gtk.ResponseType.CANCEL) as Gtk.Button;
			cancel.clicked.connect (() => { destroy (); });
		}
	}
}