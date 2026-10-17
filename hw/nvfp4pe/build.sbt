// Standalone NVFP4 PE (M6.1 Phase B). Pinned to match Chipyard 1.14 / chipyard-mx.
val chiselVersion = "6.7.0"

ThisBuild / scalaVersion := "2.13.16"
ThisBuild / version := "0.1.0"

lazy val root = (project in file("."))
  .settings(
    name := "nvfp4pe",
    libraryDependencies ++= Seq(
      "org.chipsalliance" %% "chisel" % chiselVersion,
      "org.scalatest" %% "scalatest" % "3.2.17" % Test
    ),
    scalacOptions ++= Seq("-deprecation", "-feature", "-unchecked", "-language:reflectiveCalls"),
    addCompilerPlugin("org.chipsalliance" % "chisel-plugin" % chiselVersion cross CrossVersion.full),
    Test / fork := false
  )
