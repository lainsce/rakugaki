/*
* Copyright (c) 2017 Lains
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
*
* Co-authored by: Corentin Noël <corentin@elementary.io>
*
*/

public class Rakugaki.EditableLabel : Gtk.EventBox {
    public signal void changed (string new_title);
    public Gtk.Label title;
    private Gtk.Entry entry;
    private Gtk.Stack stack;
    private Gtk.Grid grid;

    public string text {
        get {
            return title.label;
        }

        set {
            title.label = value;
        }
    }

    private bool editing {
        set {
            if (value) {
                entry.text = title.label;
                stack.set_visible_child (entry);
                entry.grab_focus ();
            } else {
                if (entry.text.strip () != "" && title.label != entry.text) {
                    title.label = entry.text;
                    changed (entry.text);
                }

                stack.set_visible_child (grid);
            }
        }
    }

    public EditableLabel (string? title_name) {
        events |= Gdk.EventMask.ENTER_NOTIFY_MASK;
        events |= Gdk.EventMask.LEAVE_NOTIFY_MASK;
        events |= Gdk.EventMask.BUTTON_PRESS_MASK;

        title = new Gtk.Label (title_name);
        title.valign = Gtk.Align.CENTER;
        title.width_chars = 3;
        title.ellipsize = Pango.EllipsizeMode.END;

        grid = new Gtk.Grid ();
        grid.row_homogeneous = true;
        grid.column_homogeneous = true;
        grid.valign = Gtk.Align.CENTER;
        grid.add (title);

        entry = new Gtk.Entry ();
        entry.valign = Gtk.Align.CENTER;
        entry.width_chars = 3;
        var entry_style_context = entry.get_style_context ();
        entry_style_context.add_class (Gtk.STYLE_CLASS_FLAT);

        stack = new Gtk.Stack ();
        stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        stack.hhomogeneous = false;
        stack.add (grid);
        stack.add (entry);
        add (stack);

        enter_notify_event.connect ((event) => {
            if (event.detail != Gdk.NotifyType.INFERIOR) {
                event.window.set_cursor (new Gdk.Cursor.from_name (Gdk.Display.get_default(), "text"));
            }

            return false;
        });

        leave_notify_event.connect ((event) => {
            event.window.set_cursor (new Gdk.Cursor.from_name (Gdk.Display.get_default(), "default"));

            return false;
        });

        button_release_event.connect ((event) => {
            editing = true;
            return false;
        });

        entry.activate.connect (() => {
            editing = false;
        });

        entry.focus_out_event.connect ((event) => {
            editing = false;
            return false;
        });

        entry.icon_release.connect ((p0, p1) => {
            if (p0 == Gtk.EntryIconPosition.SECONDARY) {
                editing = false;
            }
        });
    }
}
