#include "taskbar_media.h"

#include <algorithm>
#include <dwmapi.h>
#include <wincodec.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>

#include "resource.h"

#ifndef WM_DWMSENDICONICTHUMBNAIL
#define WM_DWMSENDICONICTHUMBNAIL 0x0323
#endif
#ifndef WM_DWMSENDICONICLIVEPREVIEWBITMAP
#define WM_DWMSENDICONICLIVEPREVIEWBITMAP 0x0326
#endif
#ifndef THBN_CLICKED
#define THBN_CLICKED 0x1800
#endif

namespace {

constexpr int kButtonPrev = 1;
constexpr int kButtonPlay = 2;
constexpr int kButtonNext = 3;
constexpr int kButtonLike = 4;

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int count =
      MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (count <= 1) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(count - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), count);
  return wide;
}

bool MapBool(const flutter::EncodableMap& map, const char* key, bool fallback) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return fallback;
  }
  if (const auto* value = std::get_if<bool>(&it->second)) {
    return *value;
  }
  return fallback;
}

std::string MapString(const flutter::EncodableMap& map, const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return std::string();
  }
  if (const auto* value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return std::string();
}

}  // namespace

TaskbarMedia::TaskbarMedia() {
  taskbar_created_ = RegisterWindowMessage(L"TaskbarButtonCreated");
}

TaskbarMedia::~TaskbarMedia() { Detach(); }

void TaskbarMedia::Attach(flutter::BinaryMessenger* messenger, HWND hwnd) {
  hwnd_ = hwnd;
  icon_prev_ = LoadToolbarIcon(IDI_TB_PREV);
  icon_play_ = LoadToolbarIcon(IDI_TB_PLAY);
  icon_pause_ = LoadToolbarIcon(IDI_TB_PAUSE);
  icon_next_ = LoadToolbarIcon(IDI_TB_NEXT);
  icon_like_ = LoadToolbarIcon(IDI_TB_LIKE);
  icon_liked_ = LoadToolbarIcon(IDI_TB_LIKED);

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "dev.melune.taskbar",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto& method = call.method_name();
        if (method == "update") {
          const auto* map =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (map != nullptr) {
            enabled_ = MapBool(*map, "enabled", false);
            playing_ = MapBool(*map, "playing", false);
            liked_ = MapBool(*map, "liked", false);
            EnsureTaskbar();
            AddOrUpdateButtons();
            const std::wstring tip = Utf8ToWide(MapString(*map, "title"));
            if (taskbar_ != nullptr && hwnd_ != nullptr && !tip.empty()) {
              taskbar_->SetThumbnailTooltip(hwnd_, tip.c_str());
            }
          }
          result->Success();
          return;
        }
        if (method == "artwork") {
          const auto* bytes =
              std::get_if<std::vector<uint8_t>>(call.arguments());
          if (bytes != nullptr) {
            SetArtwork(*bytes);
          } else {
            SetArtwork({});
          }
          result->Success();
          return;
        }
        result->NotImplemented();
      });

  EnsureTaskbar();
  AddOrUpdateButtons();
}

void TaskbarMedia::Detach() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
    channel_.reset();
  }
  SetIconic(false);
  if (artwork_) {
    DeleteObject(artwork_);
    artwork_ = nullptr;
  }
  if (taskbar_) {
    taskbar_->Release();
    taskbar_ = nullptr;
  }
  auto destroy_icon = [](HICON& icon) {
    if (icon) {
      DestroyIcon(icon);
      icon = nullptr;
    }
  };
  destroy_icon(icon_prev_);
  destroy_icon(icon_play_);
  destroy_icon(icon_pause_);
  destroy_icon(icon_next_);
  destroy_icon(icon_like_);
  destroy_icon(icon_liked_);
  hwnd_ = nullptr;
  buttons_added_ = false;
}

std::optional<LRESULT> TaskbarMedia::HandleMessage(HWND hwnd, UINT message,
                                                   WPARAM wparam,
                                                   LPARAM lparam) {
  if (hwnd_ == nullptr || hwnd != hwnd_) {
    return std::nullopt;
  }
  if (taskbar_created_ != 0 && message == taskbar_created_) {
    buttons_added_ = false;
    EnsureTaskbar();
    AddOrUpdateButtons();
    return 0;
  }
  if (message == WM_COMMAND && HIWORD(wparam) == THBN_CLICKED) {
    switch (LOWORD(wparam)) {
      case kButtonPrev:
        ReplyPressed("previous");
        break;
      case kButtonPlay:
        ReplyPressed("playPause");
        break;
      case kButtonNext:
        ReplyPressed("next");
        break;
      case kButtonLike:
        ReplyPressed("like");
        break;
      default:
        break;
    }
    return 0;
  }
  if (message == WM_DWMSENDICONICTHUMBNAIL && iconic_) {
    const int width = std::clamp(static_cast<int>(LOWORD(lparam)), 1, 2048);
    const int height = std::clamp(static_cast<int>(HIWORD(lparam)), 1, 2048);
    SendIconicThumbnail(hwnd, width, height);
    return 0;
  }
  if (message == WM_DWMSENDICONICLIVEPREVIEWBITMAP && iconic_) {
    SendIconicLivePreview(hwnd);
    return 0;
  }
  return std::nullopt;
}

void TaskbarMedia::EnsureTaskbar() {
  if (taskbar_ != nullptr || hwnd_ == nullptr) {
    return;
  }
  if (FAILED(CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&taskbar_)))) {
    taskbar_ = nullptr;
    return;
  }
  if (FAILED(taskbar_->HrInit())) {
    taskbar_->Release();
    taskbar_ = nullptr;
  }
}

void TaskbarMedia::AddOrUpdateButtons() {
  if (taskbar_ == nullptr || hwnd_ == nullptr) {
    return;
  }
  THUMBBUTTON buttons[4] = {};
  const bool disabled = !enabled_;
  auto fill = [&](THUMBBUTTON& button, int id, HICON icon, const wchar_t* tip) {
    button.dwMask = THB_FLAGS | THB_ICON | THB_TOOLTIP;
    button.iId = static_cast<UINT>(id);
    button.hIcon = icon;
    wcsncpy_s(button.szTip, tip, _TRUNCATE);
    button.dwFlags = disabled ? THBF_DISABLED : THBF_ENABLED;
  };
  fill(buttons[0], kButtonPrev, icon_prev_, L"\u4e0a\u4e00\u9996");
  fill(buttons[1], kButtonPlay, playing_ ? icon_pause_ : icon_play_,
       playing_ ? L"\u6682\u505c" : L"\u64ad\u653e");
  fill(buttons[2], kButtonNext, icon_next_, L"\u4e0b\u4e00\u9996");
  fill(buttons[3], kButtonLike, liked_ ? icon_liked_ : icon_like_,
       liked_ ? L"\u53d6\u6d88\u559c\u6b22" : L"\u559c\u6b22");

  if (!buttons_added_) {
    if (SUCCEEDED(taskbar_->ThumbBarAddButtons(hwnd_, 4, buttons))) {
      buttons_added_ = true;
    }
  } else {
    taskbar_->ThumbBarUpdateButtons(hwnd_, 4, buttons);
  }
}

void TaskbarMedia::SetIconic(bool enabled) {
  if (hwnd_ == nullptr) {
    return;
  }
  BOOL has_bitmap = enabled ? TRUE : FALSE;
  BOOL force = FALSE;
  DwmSetWindowAttribute(hwnd_, DWMWA_HAS_ICONIC_BITMAP, &has_bitmap,
                        sizeof(has_bitmap));
  DwmSetWindowAttribute(hwnd_, DWMWA_FORCE_ICONIC_REPRESENTATION, &force,
                        sizeof(force));
  const bool changed = iconic_ != enabled;
  iconic_ = enabled;
  if (enabled && changed) {
    DwmInvalidateIconicBitmaps(hwnd_);
  }
}

void TaskbarMedia::SetArtwork(const std::vector<uint8_t>& bytes) {
  if (artwork_) {
    DeleteObject(artwork_);
    artwork_ = nullptr;
  }
  if (!bytes.empty()) {
    artwork_ = DecodeImage(bytes);
  }
  SetIconic(artwork_ != nullptr);
  if (artwork_ != nullptr && hwnd_ != nullptr) {
    DwmInvalidateIconicBitmaps(hwnd_);
  }
}

HBITMAP TaskbarMedia::DecodeImage(const std::vector<uint8_t>& bytes) {
  IWICImagingFactory* factory = nullptr;
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory)))) {
    return nullptr;
  }
  IWICStream* stream = nullptr;
  IWICBitmapDecoder* decoder = nullptr;
  IWICBitmapFrameDecode* frame = nullptr;
  IWICFormatConverter* converter = nullptr;
  HBITMAP bitmap = nullptr;
  auto done = [&]() {
    if (converter) {
      converter->Release();
    }
    if (frame) {
      frame->Release();
    }
    if (decoder) {
      decoder->Release();
    }
    if (stream) {
      stream->Release();
    }
    if (factory) {
      factory->Release();
    }
    return bitmap;
  };
  if (FAILED(factory->CreateStream(&stream)) ||
      FAILED(stream->InitializeFromMemory(
          const_cast<BYTE*>(bytes.data()),
          static_cast<DWORD>(bytes.size()))) ||
      FAILED(factory->CreateDecoderFromStream(
          stream, nullptr, WICDecodeMetadataCacheOnLoad, &decoder)) ||
      FAILED(decoder->GetFrame(0, &frame)) ||
      FAILED(factory->CreateFormatConverter(&converter)) ||
      FAILED(converter->Initialize(frame, GUID_WICPixelFormat32bppPBGRA,
                                   WICBitmapDitherTypeNone, nullptr, 0.0,
                                   WICBitmapPaletteTypeCustom))) {
    return done();
  }
  UINT width = 0;
  UINT height = 0;
  converter->GetSize(&width, &height);
  if (width == 0 || height == 0) {
    return done();
  }
  BITMAPINFO info = {};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = static_cast<LONG>(width);
  info.bmiHeader.biHeight = -static_cast<LONG>(height);
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  void* bits = nullptr;
  bitmap = CreateDIBSection(nullptr, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
  if (bitmap == nullptr || bits == nullptr) {
    bitmap = nullptr;
    return done();
  }
  const UINT stride = width * 4;
  if (FAILED(converter->CopyPixels(nullptr, stride, stride * height,
                                   static_cast<BYTE*>(bits)))) {
    DeleteObject(bitmap);
    bitmap = nullptr;
  }
  return done();
}

HBITMAP TaskbarMedia::CreatePreviewBitmap(int width, int height) {
  width = std::clamp(width, 1, 2048);
  height = std::clamp(height, 1, 2048);
  HDC screen = GetDC(nullptr);
  if (screen == nullptr) {
    return nullptr;
  }
  HDC dest_dc = CreateCompatibleDC(screen);
  HBITMAP dest = CreateCompatibleBitmap(screen, width, height);
  if (dest_dc == nullptr || dest == nullptr) {
    if (dest) {
      DeleteObject(dest);
    }
    if (dest_dc) {
      DeleteDC(dest_dc);
    }
    ReleaseDC(nullptr, screen);
    return nullptr;
  }
  HGDIOBJ old_dest = SelectObject(dest_dc, dest);
  RECT fill = {0, 0, width, height};
  HBRUSH brush = CreateSolidBrush(RGB(28, 24, 38));
  FillRect(dest_dc, &fill, brush);
  DeleteObject(brush);
  BITMAP info = {};
  if (artwork_ != nullptr && GetObject(artwork_, sizeof(info), &info) &&
      info.bmWidth > 0 && info.bmHeight > 0) {
    const double scale = std::min(static_cast<double>(width) / info.bmWidth,
                                  static_cast<double>(height) / info.bmHeight);
    const int draw_w = std::max(1, static_cast<int>(info.bmWidth * scale));
    const int draw_h = std::max(1, static_cast<int>(info.bmHeight * scale));
    const int x = (width - draw_w) / 2;
    const int y = (height - draw_h) / 2;
    HDC source_dc = CreateCompatibleDC(screen);
    HGDIOBJ old_source = SelectObject(source_dc, artwork_);
    SetStretchBltMode(dest_dc, HALFTONE);
    SetBrushOrgEx(dest_dc, 0, 0, nullptr);
    StretchBlt(dest_dc, x, y, draw_w, draw_h, source_dc, 0, 0, info.bmWidth,
               info.bmHeight, SRCCOPY);
    SelectObject(source_dc, old_source);
    DeleteDC(source_dc);
  }
  SelectObject(dest_dc, old_dest);
  DeleteDC(dest_dc);
  ReleaseDC(nullptr, screen);
  return dest;
}

bool TaskbarMedia::SendIconicThumbnail(HWND hwnd, int width, int height) {
  HBITMAP preview = CreatePreviewBitmap(width, height);
  if (preview == nullptr) {
    return false;
  }
  const HRESULT hr = DwmSetIconicThumbnail(hwnd, preview, 0);
  DeleteObject(preview);
  return SUCCEEDED(hr);
}

bool TaskbarMedia::SendIconicLivePreview(HWND hwnd) {
  RECT client = {};
  GetClientRect(hwnd, &client);
  const int width = std::max(1, static_cast<int>(client.right - client.left));
  const int height = std::max(1, static_cast<int>(client.bottom - client.top));
  HBITMAP preview = CreatePreviewBitmap(width, height);
  if (preview == nullptr) {
    return false;
  }
  POINT origin = {0, 0};
  const HRESULT hr = DwmSetIconicLivePreviewBitmap(hwnd, preview, &origin, 0);
  DeleteObject(preview);
  return SUCCEEDED(hr);
}

HICON TaskbarMedia::LoadToolbarIcon(int resource_id) {
  return static_cast<HICON>(LoadImage(GetModuleHandle(nullptr),
                                      MAKEINTRESOURCE(resource_id), IMAGE_ICON,
                                      16, 16, LR_DEFAULTCOLOR));
}

void TaskbarMedia::ReplyPressed(const std::string& action) {
  if (!channel_) {
    return;
  }
  channel_->InvokeMethod("pressed",
                         std::make_unique<flutter::EncodableValue>(action));
}
