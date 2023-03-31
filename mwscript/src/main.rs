use clap::{Parser, Subcommand};
use mwscript::{dump, serialize_plugin, ESerializedType};
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

        /// Include specific records
        #[arg(short, long)]
        include: Vec<String>,

        /// Exclude specific records
        #[arg(short, long)]
        exclude: Vec<String>,

        /// The extension to serialize to, default is yaml
        #[arg(short, long, value_enum)]
        format: ESerializedType,
    },

    /// Dump scripts from a plugin.
    Serialize {
        /// input path, may be a plugin or a folder
        input: Option<PathBuf>,

        /// output directory to dump scripts to, defaults to cwd
        #[arg(short, long)]
        output: Option<PathBuf>,

        /// The extension to serialize to, default is yaml
        #[arg(short, long, value_enum)]
        format: ESerializedType,
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
            include,
            exclude,
            format,
        } => match dump(input, output, *create, include, exclude, format) {
            Ok(_) => println!("Done."),
            Err(err) => println!("Error dumping scripts: {}", err),
        },
        Commands::Serialize {
            input,
            output,
            format,
        } => match serialize_plugin(input, output, format) {
            Ok(_) => println!("Done."),
            Err(err) => println!("Error dumping scripts: {}", err),
        },
    }
}
