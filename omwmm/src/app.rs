use std::{
    fs::File,
    io::Write,
    path::{Path, PathBuf},
};

use egui_notify::Toasts;
use log::{error, info, warn};

use crate::{get_openmwcfg, read_lines, EScale, ModInfo};

/// We derive Deserialize/Serialize so we can persist app state on shutdown.
#[derive(serde::Deserialize, serde::Serialize)]
#[serde(default)]
pub struct TemplateApp {
    // ui
    pub light_mode: bool,
    pub scale: EScale,
    #[serde(skip)]
    pub toasts: Toasts,
    // app
    /// the folder where mod archives are stored
    pub downloads_library: Option<String>,
    /// runtime cache of mod archive paths
    #[serde(skip)]
    pub downloads: Vec<PathBuf>,

    /// the folder where mods are extracted to
    pub mods_library: Option<String>,
    /// info which mods are available
    pub mods: Vec<ModInfo>,

    /// enabled plugins. this can be a list
    pub enabled_plugins: Vec<String>,
    pub enabled_mods: Vec<String>,
}

impl Default for TemplateApp {
    fn default() -> Self {
        Self {
            light_mode: false,
            scale: EScale::Small,
            toasts: Toasts::default(),
            downloads_library: None,
            downloads: vec![],
            mods_library: None,
            mods: vec![],
            enabled_plugins: vec![],
            enabled_mods: vec![],
        }
    }
}

impl TemplateApp {
    /// Called once before the first frame.
    pub fn new(cc: &eframe::CreationContext<'_>) -> Self {
        // This is also where you can customize the look and feel of egui using
        // `cc.egui_ctx.set_visuals` and `cc.egui_ctx.set_fonts`.
        //cc.egui_ctx.set_pixels_per_point(2.0_f32);

        // simple_logger::init().unwrap();

        // Load previous app state (if any).
        // Note that you must enable the `persistence` feature for this to work.
        if let Some(storage) = cc.storage {
            return eframe::get_value(storage, eframe::APP_KEY).unwrap_or_default();
        }

        Default::default()
    }

    // UI methods

    pub fn update_top_panel(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        egui::TopBottomPanel::top("top_panel").show(ctx, |ui| {
            self.menu_bar_view(ui, frame);
        });
    }

    pub fn update_right_side_panel(&mut self, ctx: &egui::Context) {
        egui::SidePanel::right("side_panel")
            //.min_width(250_f32)
            .show(ctx, |ui| {
                self.combined_side_view(ui);
            });
    }

    pub fn update_central_panel(&mut self, ctx: &egui::Context) {
        egui::CentralPanel::default().show(ctx, |ui| {
            self.main_view(ui);
        });
    }

    // Logic

    /// refreshes the downloads list by walking the downloads library
    pub fn refresh_downloads(&mut self, library_path: String) {
        // TODO get files
        // TODO make proper viewmodels
        // TODO remove dbg
        self.downloads
            .push(Path::new(&library_path.as_str()).join("dbg1.zip"));
        self.downloads
            .push(Path::new(&library_path.as_str()).join("dbg2.zip"));
    }

    /// updates the openmw.cfg's content= and data= entries
    /// goes through the enabled mods and adds data= entries for each
    /// goes through the enbaled plugins and adds content= entries for each
    ///
    pub fn update_cfg(&mut self) -> bool {
        // TODO use per-profile configs?

        // find omw cfg
        if let Some(cfg_path) = get_openmwcfg() {
            // get everything that is not a content line
            info!("Parsing cfg {} ...", cfg_path.display());
            let mut original_cfg: Vec<String> = vec![];
            if let Ok(lines) = read_lines(&cfg_path) {
                for line in lines.flatten() {
                    // parse each line
                    if line.starts_with("data=") {
                        // TODO can we check this better?
                        if line.ends_with("Data Files\"") {
                            original_cfg.push(line);
                        }
                    } else if line.starts_with("content=") {
                        // ignore vanilla esms
                        if line.ends_with("Morrowind.esm")
                            || line.ends_with("Bloodmoon.esm")
                            || line.ends_with("Tribunal.esm")
                        {
                            original_cfg.push(line);
                        }
                    } else {
                        original_cfg.push(line);
                    }
                }
            } else {
                error!("Could not parse cfg file {}", cfg_path.display());
                return false;
            }
            // reassemble cfg
            if let Ok(mut file) = File::create(&cfg_path) {
                // write original lines
                for line in original_cfg {
                    // TODO proper eol
                    let line_with_eol = format!("{}\n", line);
                    match file.write(line_with_eol.as_bytes()) {
                        Ok(_) => {}
                        Err(err) => warn!("Error writing line {}: {}", line, err),
                    }
                }

                // write data
                for m in &self.enabled_mods {
                    // TODO proper eol
                    let data_line = format!("data=\"{}\"\n", m);
                    match file.write(data_line.as_bytes()) {
                        Ok(_) => {}
                        Err(err) => warn!("Error writing plugin {}: {}", m, err),
                    }
                }
                // write plugins
                for p in &self.enabled_plugins {
                    // TODO proper eol
                    let content_line = format!("content={}\n", p);
                    match file.write(content_line.as_bytes()) {
                        Ok(_) => {}
                        Err(err) => warn!("Error writing plugin {}: {}", p, err),
                    }
                }
            } else {
                error!("Could not write cfg file {}", cfg_path.display());
                return false;
            }
        }

        false
    }
}
