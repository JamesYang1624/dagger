#!/bin/bash

set -eu

readonly MVN_GOAL="$1"
readonly VERSION_NAME="$2"
shift 2
readonly EXTRA_MAVEN_ARGS=("$@")

bazel_output_file() {
  local library=$1
  local output_file=bazel-bin/$library
  if [[ ! -e $output_file ]]; then
     output_file=bazel-genfiles/$library
  fi
  if [[ ! -e $output_file ]]; then
    echo "Could not find bazel output file for $library"
    exit 1
  fi
  echo -n $output_file
}

# Builds and deploys the given artifacts to a configured maven goal.
# @param {string} library the library to deploy.
# @param {string} pomfile the pom file to deploy.
# @param {string} srcjar the sources jar of the library. This is an optional
# parameter, if provided then javadoc must also be provided.
# @param {string} javadoc the java doc jar of the library. This is an optional
# parameter, if provided then srcjar must also be provided.
deploy_library() {
  local arg_count=$#
  local library=$1
  local pomfile=$2

  bazel build --define=pom_version="$VERSION_NAME" \
    $library $pomfile

  # TODO(user): Consider moving this into the "gen_maven_artifact" macro, this
  # requires having the version checked-in for the build system.
  add_tracking_version \
    $(bazel_output_file $library) \
    $(bazel_output_file $pomfile)

  if [ $arg_count == 4 ] ; then
    local srcjar=$3
    local javadoc=$4
    bazel build --define=pom_version="$VERSION_NAME" \
      $srcjar $javadoc
    mvn $MVN_GOAL \
      -Dfile=$(bazel_output_file $library) \
      -Djavadoc=$(bazel_output_file $javadoc) \
      -DpomFile=$(bazel_output_file $pomfile) \
      -Dsources=$(bazel_output_file $srcjar) \
      "${EXTRA_MAVEN_ARGS[@]:+${EXTRA_MAVEN_ARGS[@]}}"
  else
    mvn $MVN_GOAL \
      -Dfile=$(bazel_output_file $library) \
      -DpomFile=$(bazel_output_file $pomfile) \
      "${EXTRA_MAVEN_ARGS[@]:+${EXTRA_MAVEN_ARGS[@]}}"
  fi
}

add_tracking_version() {
  local library=$1
  local pomfile=$2
  local group_id=$(find_pom_value $pomfile "groupId")
  local artifact_id=$(find_pom_value $pomfile "artifactId")
  local temp_dir=$(mktemp -d)
  local version_file="META-INF/${group_id}_${artifact_id}.version"
  mkdir -p "$temp_dir/META-INF/"
  echo $VERSION_NAME >> "$temp_dir/$version_file"
  if [[ $library =~ \.jar$ ]]; then
    jar uf $library -C $temp_dir $version_file
  elif [[ $library =~ \.aar$ ]]; then
    unzip $library classes.jar -d $temp_dir
    jar uf $temp_dir/classes.jar -C $temp_dir $version_file
    jar uf $library -C $temp_dir classes.jar
  else
    echo "Could not add tracking version file to $library"
    exit 1
  fi
}

find_pom_value() {
  local pomfile=$1
  local attribute=$2
  # Using Python here because `mvn help:evaluate` doesn't work with our gen pom
  # files since they don't include the aar packaging plugin.
  python $(dirname $0)/find_pom_value.py $pomfile $attribute
}

deploy_library \
  java/dagger/libcore.jar \
  java/dagger/pom.xml \
  java/dagger/libcore-src.jar \
  java/dagger/core-javadoc.jar

deploy_library \
  gwt/libgwt.jar \
  gwt/pom.xml \
  gwt/libgwt.jar \
  gwt/libgwt.jar


deploy_library \
  java/dagger/internal/codegen/artifact.jar \
  java/dagger/internal/codegen/pom.xml \
  java/dagger/internal/codegen/artifact-src.jar \
  java/dagger/internal/codegen/artifact-javadoc.jar

deploy_library \
  java/dagger/producers/artifact.jar \
  java/dagger/producers/pom.xml \
  java/dagger/producers/artifact-src.jar \
  java/dagger/producers/artifact-javadoc.jar

deploy_library \
  java/dagger/spi/artifact.jar \
  java/dagger/spi/pom.xml \
  java/dagger/spi/artifact-src.jar \
  java/dagger/spi/artifact-javadoc.jar

deploy_library \
  java/dagger/android/android.aar \
  java/dagger/android/pom.xml \
  java/dagger/android/libandroid-src.jar \
  java/dagger/android/android-javadoc.jar

deploy_library \
  java/dagger/android/android-legacy.aar \
  java/dagger/android/legacy-pom.xml

# b/37741866 and https://github.com/google/dagger/issues/715
deploy_library \
  java/dagger/android/libandroid.jar \
  java/dagger/android/jarimpl-pom.xml \
  java/dagger/android/libandroid-src.jar \
  java/dagger/android/android-javadoc.jar

deploy_library \
  java/dagger/android/support/support.aar \
  java/dagger/android/support/pom.xml \
  java/dagger/android/support/libsupport-src.jar \
  java/dagger/android/support/support-javadoc.jar

deploy_library \
  java/dagger/android/support/support-legacy.aar \
  java/dagger/android/support/legacy-pom.xml

deploy_library \
  shaded_android_processor.jar \
  java/dagger/android/processor/pom.xml \
  java/dagger/android/processor/libprocessor-src.jar \
  java/dagger/android/processor/processor-javadoc.jar

deploy_library \
  java/dagger/grpc/server/libserver.jar \
  java/dagger/grpc/server/server-pom.xml \
  java/dagger/grpc/server/libserver-src.jar \
  java/dagger/grpc/server/javadoc.jar

deploy_library \
  java/dagger/grpc/server/libannotations.jar \
  java/dagger/grpc/server/annotations-pom.xml \
  java/dagger/grpc/server/libannotations-src.jar \
  java/dagger/grpc/server/javadoc.jar

deploy_library \
  shaded_grpc_server_processor.jar \
  java/dagger/grpc/server/processor/pom.xml \
  java/dagger/grpc/server/processor/libprocessor-src.jar \
  java/dagger/grpc/server/processor/javadoc.jar
