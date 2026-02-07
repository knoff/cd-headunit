import asyncio
import time
import random
import settings_manager

class MockHardware:
    # States
    IDLE = "IDLE"
    HEATING = "HEATING"
    EXTRACTION = "EXTRACTION"
    CLEANING = "CLEANING"
    FLUSH = "FLUSH"
    ERROR = "ERROR"
    DONE = "DONE"
    STOPPED = "STOPPED"

    def __init__(self):
        self.telemetry_updated = asyncio.Event()
        self.groups = {
            "left": {"state": self.IDLE, "start_time": 0, "profile": None, "last_frame": None},
            "right": {"state": self.IDLE, "start_time": 0, "profile": None, "last_frame": None}
        }

    async def get_telemetry(self):
        res = {
            "machine": {
                "boiler_temp": 95.5,
                "steam_pressure": 1.2,
                "water_level": "ok"
            }
        }
        for side in ["left", "right"]:
            g = self.groups[side]
            state = g["state"]

            if state == self.IDLE:
                res[side] = {
                    "temp": 93.0, "pressure": 0.0, "flowIn": 0.0, "flowOut": 0.0,
                    "yield": 0.0, "time": "0:00", "done": False, "active": False,
                    "state": self.IDLE
                }
            elif state in [self.DONE, self.STOPPED]:
                # Возвращаем последний зафиксированный кадр экстракции
                if g["last_frame"]:
                    res[side] = {**g["last_frame"], "state": state, "active": False}
                else:
                    res[side] = {
                        "temp": 93.0, "pressure": 0.0, "flowIn": 0.0, "flowOut": 0.0,
                        "yield": 0.0, "time": "0:00", "done": False, "active": False,
                        "state": state
                    }

                # Авто-уход в IDLE (защита бэкенда)
                settings = settings_manager.get_settings()
                timeout = int(settings.get("summary_timeout", 15))

                # Если timeout == 0, значит Summary отключен (сразу в IDLE)
                # Иначе ждем указанное время
                if timeout == 0 or (time.time() - g["start_time"] > timeout):
                    g["state"] = self.IDLE
            elif state == self.EXTRACTION:
                elapsed = time.time() - g["start_time"]
                done = elapsed > 30

                frame = {
                    "temp": round(93.0 + random.uniform(-0.1, 0.1), 1),
                    "pressure": round(9.0 if elapsed > 2 else elapsed * 4.5, 1),
                    "flowIn": 2.5,
                    "flowOut": 2.2,
                    "yield": round(elapsed * 2.2, 1),
                    "time": f"{int(elapsed // 60)}:{int(elapsed % 60):02d}",
                    "done": done,
                    "active": True,
                    "state": self.EXTRACTION
                }
                res[side] = frame
                g["last_frame"] = frame # Сохраняем для Summary

                if done:
                    g["state"] = self.DONE
                    g["start_time"] = time.time() # Таймер для выхода из DONE
            else:
                # Другие состояния (HEATING, CLEANING, и т.д.)
                res[side] = {
                    "temp": 93.0, "pressure": 0.0, "flowIn": 0.0, "flowOut": 0.0,
                    "yield": 0.0, "time": "0:00", "done": False, "active": True,
                    "state": state
                }
        return res

    def start_extraction(self, side, profile):
        if side in self.groups and self.groups[side]["state"] == self.IDLE:
            self.groups[side]["state"] = self.EXTRACTION
            self.groups[side]["start_time"] = time.time()
            self.groups[side]["profile"] = profile
            self.telemetry_updated.set()

    def stop_extraction(self, side):
        if side in self.groups:
            current_state = self.groups[side]["state"]
            if current_state == self.EXTRACTION:
                self.groups[side]["state"] = self.STOPPED
                self.groups[side]["start_time"] = time.time()
                self.telemetry_updated.set()
            elif current_state in [self.FLUSH, self.CLEANING]:
                self.groups[side]["state"] = self.IDLE
                self.groups[side]["last_frame"] = None
                self.telemetry_updated.set()

    def start_flush(self, side):
        if side in self.groups and self.groups[side]["state"] == self.IDLE:
            self.groups[side]["state"] = self.FLUSH
            self.groups[side]["start_time"] = time.time()
            self.telemetry_updated.set()

    def start_cleaning(self, side):
        if side in self.groups and self.groups[side]["state"] == self.IDLE:
            self.groups[side]["state"] = self.CLEANING
            self.groups[side]["start_time"] = time.time()
            self.telemetry_updated.set()

    def reset_group(self, side):
        if side in self.groups:
            self.groups[side]["state"] = self.IDLE
            self.groups[side]["last_frame"] = None
            self.telemetry_updated.set()
