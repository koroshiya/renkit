use std::path::PathBuf;

use anyhow::Result;
use clap::{Parser, Subcommand};
use renkit::renotize::unpack_app;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Utility method to provision required information for notarization using a step-by-step process.
    Provision,
    /// Unpacks the given ZIP file to the target directory.
    UnpackApp {
        input_file: PathBuf,
        output_dir: PathBuf,
        bundle_id: String,
    },
    /// Signs a .app bundle with the given Developer Identity.
    SignApp {
        input_file: PathBuf,
        #[arg(short = 'k', long)]
        key_file: PathBuf,
        #[arg(short = 'c', long)]
        cert_file: PathBuf,
    },
    /// Notarizes a .app bundle with the given Developer Account and bundle ID.
    NotarizeApp {
        input_file: PathBuf,
        #[arg(short = 'k', long)]
        app_store_key_file: PathBuf,
    },
    /// Packages a .app bundle into a .dmg file.
    PackDmg {
        input_file: PathBuf,
        #[arg(short = 'o', long)]
        output_file: PathBuf,
        #[arg(short = 'v', long)]
        volume_name: Option<String>,
    },
    /// Signs a .dmg file with the given Developer Identity.
    SignDmg {
        input_file: PathBuf,
        #[arg(short = 'k', long)]
        key_file: PathBuf,
        #[arg(short = 'c', long)]
        cert_file: PathBuf,
    },
    /// Notarizes a .dmg file with the given Developer Account and bundle ID.
    NotarizeDmg {
        input_file: PathBuf,
        #[arg(short = 'k', long)]
        app_store_key_file: PathBuf,
    },
    /// Checks the status of a notarization operation given its UUID.
    Status {
        #[arg(short = 'u', long)]
        uuid: String,
        #[arg(short = 'k', long)]
        app_store_key_file: PathBuf,
    },
    /// Fully notarize a given .app bundle, creating a signed and notarized artifact for distribution.
    FullRun {
        input_file: PathBuf,
        #[arg(short = 'b', long)]
        bundle_id: String,
        #[arg(short = 'k', long)]
        key_file: PathBuf,
        #[arg(short = 'c', long)]
        cert_file: PathBuf,
        #[arg(short = 'a', long)]
        app_store_key_file: PathBuf,
        #[arg(short = 'j', long)]
        json_bundle_file: Option<PathBuf>,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match &cli.command {
        Commands::Provision => {}
        Commands::UnpackApp {
            input_file,
            output_dir,
            bundle_id,
        } => unpack_app(input_file, output_dir, bundle_id).await?,
        Commands::SignApp {
            input_file,
            key_file,
            cert_file,
        } => {}
        Commands::NotarizeApp {
            input_file,
            app_store_key_file,
        } => {}
        Commands::PackDmg {
            input_file,
            output_file,
            volume_name,
        } => {}
        Commands::SignDmg {
            input_file,
            key_file,
            cert_file,
        } => {}
        Commands::NotarizeDmg {
            input_file,
            app_store_key_file,
        } => {}
        Commands::Status {
            uuid,
            app_store_key_file,
        } => {}
        Commands::FullRun {
            input_file,
            bundle_id,
            key_file,
            cert_file,
            app_store_key_file,
            json_bundle_file,
        } => {}
    }

    Ok(())
}
