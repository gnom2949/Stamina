/*
 * Copyright 2026 Int Software, Aleksandr Silaev
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a license for this program. If not, see
 * <http://www.gnu.org/licenses/>.
 */

namespace Stamina {
    public class Timer : Object {
        public int remaining_seconds { get; private set; }
        public int total_seconds { get; private set; }
        public bool is_running { get; private set; }
        public bool is_work_time { get; private set; }
        public int completed_sessions { get; private set; }
        public int completed_breaks { get; private set; }

        private uint timeout_id = 0;
        private Settings settings;

        public signal void tick ();
        public signal void completed ();

        public Timer (Settings settings)
        {
            this.settings = settings;

            // Значения по умолчанию
            remaining_seconds = settings.get_int ("work-duration") * 60;
            total_seconds = remaining_seconds;
            is_work_time = true;
            is_running = false;
            completed_sessions = 0;
            completed_breaks = 0;
        }

        public void start ()
        {
            if (!is_running) {
                is_running = true;
                timeout_id = Timeout.add (1000, on_timeout);
            }
        }

        public void pause ()
        {
            if (is_running) {
                is_running = false;
                if (timeout_id > 0) {
                    Source.remove (timeout_id);
                    timeout_id = 0;
                }
            }
        }

        public void reset ()
        {
            pause ();
            remaining_seconds = is_work_time ?
                settings.get_int ("work-duration") * 60 :
                settings.get_int ("break-duration") * 60;
            total_seconds = remaining_seconds;
        }

        public void start_break (bool is_long)
        {
            pause ();
            is_work_time = false;
            remaining_seconds = is_long ?
                settings.get_int ("long-break-duration") * 60 :
                settings.get_int ("break-duration") * 60;
            total_seconds = remaining_seconds;
        }

        private bool on_timeout ()
        {
            if (remaining_seconds > 0) {
                remaining_seconds--;
                tick ();

                // Сохранение каждые 30 секунд
                if (remaining_seconds % 30 == 0) {
                    save_state ();
                }
            } else {
                pause ();
                completed ();

                if (is_work_time) {
                    completed_sessions++;
                    if (settings.get_boolean ("auto-start-break")) {
                        start_break (completed_sessions % 4 == 0);
                        if (settings.get_boolean ("auto-start-timer")) {
                            start ();
                        }
                    }
                } else {
                    completed_breaks++;
                    if (settings.get_boolean ("auto-start-work")) {
                        is_work_time = true;
                        remaining_seconds = settings.get_int ("work-duration") * 60;
                        total_seconds = remaining_seconds;
                        if (settings.get_boolean ("auto-start-timer")) {
                            start ();
                        }
                    }
                }

                save_state ();
                return false;
            }

            return true;
        }

        public void save_state ()
        {
            settings.set_int ("remaining-seconds", remaining_seconds);
            settings.set_int ("total-seconds", total_seconds);
            settings.set_boolean ("is-work-time", is_work_time);
            settings.set_boolean ("is-running", is_running);
            settings.set_int ("completed-sessions", completed_sessions);
            settings.set_int ("completed-breaks", completed_breaks);
            settings.set_string ("last-saved", new DateTime.now_local ().to_string ());
        }

        public void load_state ()
        {
            remaining_seconds = settings.get_int ("remaining-seconds");
            if (remaining_seconds == 0) {
                remaining_seconds = settings.get_int ("work-duration") * 60;
            }

            total_seconds = settings.get_int ("total-seconds");
            if (total_seconds == 0) {
                total_seconds = settings.get_int ("work-duration") * 60;
            }

            is_work_time = settings.get_boolean ("is-work-time");
            is_running = settings.get_boolean ("is-running");
            completed_sessions = settings.get_int ("completed-sessions");
            completed_breaks = settings.get_int ("completed-breaks");

            if (is_running) {
                start ();
            }
        }
    }
}
