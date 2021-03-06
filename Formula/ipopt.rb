class Ipopt < Formula
  desc "Interior point optimizer"
  homepage "https://coin-or.github.io/Ipopt/"
  url "https://www.coin-or.org/download/source/Ipopt/Ipopt-3.13.3.tgz"
  sha256 "86354b36c691e6cd6b8049218519923ab0ce8a6f0a432c2c0de605191f2d4a1c"
  license "EPL-1.0"
  head "https://github.com/coin-or/Ipopt.git"

  bottle do
    cellar :any
    rebuild 1
    sha256 "a62daecc2de45ee50a282c0d7640a9c3a84b8eccd14d09f7a73da81e794ce367" => :catalina
    sha256 "1810190042322bc95d70e8eb7b430f5833dfe0ecb4c93652dd2d02a8a2097df8" => :mojave
    sha256 "cb84dcb56e82cfc9d3d20f073e91ca6cb91bfbd4b6870ba006a614a4326835de" => :high_sierra
  end

  depends_on "pkg-config" => [:build, :test]
  depends_on "gcc"
  depends_on "openblas"

  resource "mumps" do
    url "http://mumps.enseeiht.fr/MUMPS_5.3.5.tar.gz"
    sha256 "9cf89fcb5232560e807b7b1cc2adb7d0c280cbdfd3aa480de1d0b431a87187d3"

    # MUMPS does not provide a Makefile.inc customized for macOS.
    patch do
      url "https://raw.githubusercontent.com/Homebrew/formula-patches/ab96a8b8e510a8a022808a9be77174179ac79e85/ipopt/mumps-makefile-inc-generic-seq.patch"
      sha256 "0c570ee41299073ec2232ad089d8ee10a2010e6dfc9edc28f66912dae6999d75"
    end
  end

  resource "test" do
    url "https://www.coin-or.org/download/source/Ipopt/Ipopt-3.13.3.tgz"
    sha256 "86354b36c691e6cd6b8049218519923ab0ce8a6f0a432c2c0de605191f2d4a1c"
  end

  def install
    ENV.delete("MPICC")
    ENV.delete("MPICXX")
    ENV.delete("MPIFC")

    resource("mumps").stage do
      cp "Make.inc/Makefile.inc.generic.SEQ", "Makefile.inc"
      inreplace "Makefile.inc", "@rpath/", "#{opt_lib}/"

      # Fix for GCC 10
      inreplace "Makefile.inc", "OPTF    = -fPIC", "OPTF    = -fPIC -fallow-argument-mismatch"

      ENV.deparallelize { system "make", "d" }

      (buildpath/"mumps_include").install Dir["include/*.h", "libseq/mpi.h"]
      lib.install Dir[
        "lib/#{shared_library("*")}",
        "libseq/#{shared_library("*")}",
        "PORD/lib/#{shared_library("*")}"
      ]
    end

    args = [
      "--disable-debug",
      "--disable-dependency-tracking",
      "--disable-silent-rules",
      "--enable-shared",
      "--prefix=#{prefix}",
      "--with-blas=-L#{Formula["openblas"].opt_lib} -lopenblas",
      "--with-mumps-cflags=-I#{buildpath}/mumps_include",
      "--with-mumps-lflags=-L#{lib} -ldmumps -lmpiseq -lmumps_common -lopenblas -lpord",
    ]

    system "./configure", *args
    system "make"

    ENV.deparallelize
    system "make", "install"
  end

  test do
    testpath.install resource("test")
    pkg_config_flags = `pkg-config --cflags --libs ipopt`.chomp.split
    system ENV.cxx, "examples/hs071_cpp/hs071_main.cpp", "examples/hs071_cpp/hs071_nlp.cpp", *pkg_config_flags
    system "./a.out"
  end
end
