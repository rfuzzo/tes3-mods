use crate::TemplateApp;

impl TemplateApp {
    pub fn main_view(&mut self, ui: &mut egui::Ui) {
        // library folder path
        ui.horizontal(|ui| {
            if let Some(p) = self.mods_library.clone() {
                ui.label(p.as_str());
            } else {
                ui.label("Choose mod library path ...");
            }
            if ui.button("...").clicked() {
                // TODO pick folder
                self.mods_library = Some("/Users/ghost/Documents/omwmm/mods".into());
            }
        });

        ui.separator();

        // mods view
        // TODO the library path is useless if the mods are serialized :thonk:
        if let Some(_library_path) = self.mods_library.clone() {
            // TODO mods view
            // this is the main view
            // it holds a list of installed mods (states of them vary per profile)
            // a mod can be enabled or disabled
            // the installed mods info can be serialized centrally
            // we can add a health check on app start, rest is user fault

            let mut is_any_changed = false;
            let mut to_delete: Vec<usize> = vec![];
            // TODO use a table
            egui::Grid::new("ui_mods").show(ui, |ui| {
                for (i, mod_info) in self.mods.iter_mut().enumerate() {
                    let r = ui.push_id(i, |ui| {
                        ui.horizontal(|ui| {
                            if ui.checkbox(&mut mod_info.enabled, "").changed() {
                                is_any_changed = true;
                            }
                            ui.label(mod_info.path.file_name().unwrap().to_string_lossy());
                        })
                    });
                    r.response.context_menu(|ui| {
                        // uninstall mod
                        if ui.button("Uninstall").clicked() {
                            // TODO delete the mod from the mod library
                            if mod_info.path.exists() {
                                match std::fs::remove_dir_all(mod_info.path.as_path()) {
                                    Ok(_) => {
                                        self.toasts.success("Mod removed");
                                    }
                                    Err(err) => {
                                        log::error!(
                                            "failed to remove mod {}: {}",
                                            mod_info.path.display(),
                                            err
                                        );
                                    }
                                }
                            }

                            // remove the mod from the list
                            to_delete.push(i);
                            ui.close_menu();
                        }
                    });
                    ui.end_row();
                }
            });

            // delete mods
            for idx in to_delete {
                self.mods.remove(idx);
                is_any_changed = true;
            }

            // update cfg
            if is_any_changed {
                self.enabled_mods = self
                    .mods
                    .iter()
                    .filter(|f| f.enabled)
                    .map(|e| e.path.to_string_lossy().into_owned())
                    .collect();
                self.update_cfg();
            }
        }
    }
}
