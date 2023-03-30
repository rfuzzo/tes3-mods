use clap::{Parser, Subcommand};
use mwscript::dump_scripts;
use std::path::PathBuf;

#[derive(Parser)]
#[command(author, version)]
#[command(about = "Tools for working with mwscripts", long_about = None)]
struct Cli {
    #[command(subcommand)]
    commands: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Dump scripts from a plugin.
    Dump {
        /// input path, may be a plugin or a folder
        input: Option<PathBuf>,

        /// output directory to dump scripts to, defaults to cwd
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// Create folder with plugin name, only available if input is a file
        #[arg(short, long)]
        create: bool,
    },
}

fn main() {
    let cli = Cli::parse();

    // You can check for the existence of subcommands, and if found use their
    // matches just as you would the top level cmd
    match &cli.commands {
        Commands::Dump {
            input,
            output,
            create,
        } => match dump_scripts(input, output, *create) {
            Ok(_) => println!("Done."),
            Err(err) => println!("Error dumping scripts: {}", err),
        },
    }
}
