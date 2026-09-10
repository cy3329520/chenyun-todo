// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::Deserialize;
use tauri::{AppHandle, Manager, WindowEvent};
use tauri::menu::{Menu, MenuItem};
use tauri::tray::{TrayIconBuilder, TrayIconEvent};
use tauri_plugin_notification::NotificationExt;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct NotifyPayload {
    title: String,
    body: String,
    sound: bool,
}

/// 弹出系统通知（跨平台），sound=true 时带提示音
#[tauri::command]
fn send_reminder(app: AppHandle, payload: NotifyPayload) {
    let mut builder = app
        .notification()
        .builder()
        .title(payload.title)
        .body(payload.body);
    if payload.sound {
        builder = builder.sound("default");
    }
    if let Err(e) = builder.show() {
        eprintln!("通知发送失败: {e}");
    }
}

#[tauri::command]
fn quit_app(app: AppHandle) {
    app.exit(0);
}

/// 吸附窗口到当前显示器左上/右上角（Rust 端执行，避免前端坐标与权限问题）
#[tauri::command]
fn snap_window(window: tauri::WebviewWindow, corner: String) {
    let Ok(Some(monitor)) = window.current_monitor() else {
        eprintln!("snap_window: 无法获取当前显示器");
        return;
    };
    let Ok(win_size) = window.outer_size() else { return };
    let m_pos = monitor.position();
    let m_size = monitor.size();
    let margin = (12.0 * monitor.scale_factor()).round() as i32;
    let x = if corner == "L" {
        m_pos.x + margin
    } else {
        m_pos.x + m_size.width as i32 - win_size.width as i32 - margin
    };
    let y = m_pos.y + margin;
    if let Err(e) = window.set_position(tauri::PhysicalPosition::new(x, y)) {
        eprintln!("snap_window: set_position 失败: {e}");
    }
}

fn toggle_window(app: &AppHandle) {
    if let Some(window) = app.get_webview_window("main") {
        match window.is_visible() {
            Ok(true) => {
                let _ = window.hide();
            }
            _ => {
                let _ = window.show();
                let _ = window.set_focus();
            }
        }
    }
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_notification::init())
        .invoke_handler(tauri::generate_handler![send_reminder, quit_app, snap_window])
        .setup(|app| {
            // macOS：作为后台菜单栏应用，不显示 Dock 图标
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);

            // 系统托盘菜单
            let show_item = MenuItem::with_id(app, "show", "显示 / 隐藏", true, None::<&str>)?;
            let quit_item = MenuItem::with_id(app, "quit", "退出晨云待办", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show_item, &quit_item])?;

            let mut tray_builder = TrayIconBuilder::with_id("main-tray")
                .tooltip("晨云待办")
                .menu(&menu)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "show" => toggle_window(app),
                    "quit" => app.exit(0),
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    // 单击托盘图标切换显示
                    if let TrayIconEvent::Click { .. } = event {
                        let app = tray.app_handle();
                        toggle_window(app);
                    }
                });
            if let Some(icon) = app.default_window_icon() {
                tray_builder = tray_builder.icon(icon.clone());
            }
            tray_builder.build(app)?;
            Ok(())
        })
        .on_window_event(|window, event| {
            // 点关闭按钮不退出，仅隐藏到托盘
            if let WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running 晨云待办");
}
