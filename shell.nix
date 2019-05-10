{ nixpkgs ? import <nixpkgs> {}, compiler ? "default", doBenchmark ? false }:

let

  inherit (nixpkgs) pkgs;

  f = { mkDerivation, attoparsec, base, cmark, hspec, network-uri
      , parsec, QuickCheck, rio, split, stdenv, text
      }:
      mkDerivation {
        pname = "scrapbox";
        version = "0.1.0.0";
        src = ./.;
        libraryHaskellDepends = [
          attoparsec base cmark network-uri parsec QuickCheck rio split text
        ];
        testHaskellDepends = [
          attoparsec base cmark hspec network-uri parsec QuickCheck rio split
          text
        ];
        homepage = "https://github.com/HirotoShioi/scrapbox#readme";
        description = "Renderer and parser for Scrapbox";
        license = stdenv.lib.licenses.bsd3;
      };

  haskellPackages = if compiler == "default"
                       then pkgs.haskellPackages
                       else pkgs.haskell.packages.${compiler};

  variant = if doBenchmark then pkgs.haskell.lib.doBenchmark else pkgs.lib.id;

  drv = variant (haskellPackages.callPackage f {});

in

  if pkgs.lib.inNixShell then drv.env else drv