#ifndef EXCHANGE2_PLACEMENT_H_
#define EXCHANGE2_PLACEMENT_H_

#include <windows.h>

// Logical pixels. Win32Window::Create multiplies these by the monitor scale.
struct Placement {
  int x;
  int y;
  int width;
  int height;
};

struct WorkArea {
  int x;
  int y;
  int width;
  int height;
};

inline int EnvInt(const wchar_t* name, int fallback) {
  wchar_t buffer[16];
  const DWORD length = ::GetEnvironmentVariableW(name, buffer, 16);
  if (length == 0 || length >= 16) {
    return fallback;
  }
  return ::_wtoi(buffer);
}

inline WorkArea LogicalWorkArea(double scale) {
  RECT work{};
  ::SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
  if (scale < 1) {
    scale = 1;
  }
  WorkArea area;
  area.x = static_cast<int>(work.left / scale);
  area.y = static_cast<int>(work.top / scale);
  area.width = static_cast<int>((work.right - work.left) / scale);
  area.height = static_cast<int>((work.bottom - work.top) / scale);
  if (area.width < 1) {
    area.width = 1;
  }
  if (area.height < 1) {
    area.height = 1;
  }
  return area;
}

constexpr int kGap = 16;

inline void PhoneSize(const WorkArea& area, int* width, int* height) {
  int w = 260;
  int h = 360;
  const int room_w = area.width - 2 * kGap;
  const int room_h = area.height - 2 * kGap;
  if (room_w > 0 && w > room_w / 3) {
    w = room_w / 3;
  }
  if (room_h > 0 && h > room_h / 3) {
    h = room_h / 3;
  }
  if (w < 180) {
    w = 180;
  }
  if (h < 220) {
    h = 220;
  }
  *width = w;
  *height = h;
}

// The desk, centered, small enough that a phone still fits on every side.
inline Placement PlaceSwitch(double scale) {
  const WorkArea area = LogicalWorkArea(scale);
  int phone_w = 0;
  int phone_h = 0;
  PhoneSize(area, &phone_w, &phone_h);
  int width = area.width - 2 * (phone_w + kGap);
  int height = area.height - 2 * (phone_h + kGap);
  if (width > 820) {
    width = 820;
  }
  if (height > 640) {
    height = 640;
  }
  if (width < 360) {
    width = 360;
  }
  if (height < 280) {
    height = 280;
  }
  Placement place;
  place.width = width;
  place.height = height;
  place.x = area.x + (area.width - width) / 2;
  place.y = area.y + (area.height - height) / 2;
  return place;
}

// Phone [line] of [lines], clockwise from the top of the desk.
inline Placement PlacePhone(double scale, int line, int lines) {
  const WorkArea area = LogicalWorkArea(scale);
  if (line < 1) {
    line = 1;
  }
  if (lines < line) {
    lines = line;
  }
  Placement place;
  PhoneSize(area, &place.width, &place.height);
  const Placement desk = PlaceSwitch(scale);
  const double half_w = desk.width / 2.0 + place.width / 2.0 + kGap;
  const double half_h = desk.height / 2.0 + place.height / 2.0 + kGap;
  const double cx = desk.x + desk.width / 2.0;
  const double cy = desk.y + desk.height / 2.0;
  const double distance =
      (2 * half_w + 2 * half_h) * static_cast<double>(line - 1) / lines;
  double dx;
  double dy;
  if (distance < half_w) {
    dx = distance;
    dy = -half_h;
  } else if (distance < half_w + 2 * half_h) {
    dx = half_w;
    dy = -half_h + (distance - half_w);
  } else if (distance < half_w + 2 * half_h + 2 * half_w) {
    dx = half_w - (distance - half_w - 2 * half_h);
    dy = half_h;
  } else if (distance < half_w + 2 * half_h + 2 * half_w + 2 * half_h) {
    dx = -half_w;
    dy = half_h - (distance - half_w - 2 * half_h - 2 * half_w);
  } else {
    dx = -half_w +
         (distance - half_w - 2 * half_h - 2 * half_w - 2 * half_h);
    dy = -half_h;
  }
  int x = static_cast<int>(cx + dx - place.width / 2.0);
  int y = static_cast<int>(cy + dy - place.height / 2.0);
  const int min_x = area.x + 8;
  const int min_y = area.y + 8;
  const int max_x = area.x + area.width - place.width - 8;
  const int max_y = area.y + area.height - place.height - 8;
  if (max_x >= min_x) {
    if (x < min_x) {
      x = min_x;
    }
    if (x > max_x) {
      x = max_x;
    }
  }
  if (max_y >= min_y) {
    if (y < min_y) {
      y = min_y;
    }
    if (y > max_y) {
      y = max_y;
    }
  }
  place.x = x;
  place.y = y;
  return place;
}

#endif  // EXCHANGE2_PLACEMENT_H_
