#!/usr/bin/env ruby
# Puts PrivacyInfo.xcprivacy and the localised InfoPlist.strings into the
# Runner target, so that they are actually copied into the built .app.
#
# They have always existed on disk. Existing on disk does nothing: Xcode
# copies what project.pbxproj lists in the Resources build phase, and
# `flutter create` never listed these because it never made them. The result
# builds and runs and passes every test, and then App Store Connect rejects
# the upload for a missing privacy manifest - after the binary has gone up.
# CI now checks inside the built bundle, which is how this was found.
#
# Scripted rather than hand-edited because project.pbxproj is a graph of
# 24-character hex identities, and a corrupted one is not obvious until an
# Xcode that cannot be opened here refuses to open it.
#
# Idempotent: run it twice and the second run reports nothing to do.
#
#   gem install xcodeproj
#   ruby tool/wire_ios_resources.rb ledger grove

require 'xcodeproj'

def wire(root, app)
  project_path = File.join(root, 'ios', 'Runner.xcodeproj')
  unless File.directory?(project_path)
    puts "#{app}: no Xcode project, skipping"
    return
  end
  project = Xcodeproj::Project.open(project_path)

  target = project.targets.find { |t| t.name == 'Runner' }
  abort "#{app}: no Runner target" if target.nil?

  runner_group = project.main_group['Runner']
  abort "#{app}: no Runner group" if runner_group.nil?

  resources = target.resources_build_phase
  changes = []

  # The privacy manifest: an ordinary file reference in the Runner group, added
  # to Resources. Apple requires it of every app since 2024, including one that
  # collects nothing.
  privacy = 'PrivacyInfo.xcprivacy'
  # Only ever reference a file that is actually there. Adding a reference to a
  # missing file does not fail here - it fails in Xcode, on somebody else's
  # machine, with a build error about a resource that was never written.
  if !File.exist?(File.join(root, 'ios', 'Runner', privacy))
    puts "#{app}: no #{privacy} on disk, skipping it"
  elsif resources.files_references.none? { |r| r.path == privacy }
    reference = runner_group.files.find { |f| f.path == privacy } ||
                runner_group.new_reference(privacy)
    resources.add_file_reference(reference)
    changes << "added #{privacy} to Resources"
  end

  # The localised app name is not a plain file. A set of <lang>.lproj files with
  # one name is a PBXVariantGroup - the thing Xcode shows as a single row with
  # languages folded underneath - and the group, not its children, is what goes
  # into the build phase.
  strings = 'InfoPlist.strings'
  languages = %w[en ko].select do |language|
    File.exist?(File.join(root, 'ios', 'Runner', "#{language}.lproj", strings))
  end

  if languages.empty?
    puts "#{app}: no <lang>.lproj/#{strings} on disk, skipping those"
    report(app, changes, project, project_path)
    return
  end

  variant = runner_group.children.find do |child|
    child.is_a?(Xcodeproj::Project::Object::PBXVariantGroup) && child.name == strings
  end

  if variant.nil?
    variant = project.new(Xcodeproj::Project::Object::PBXVariantGroup)
    variant.name = strings
    variant.source_tree = '<group>'
    runner_group << variant
    changes << "created the #{strings} variant group"
  end

  languages.each do |language|
    next if variant.children.any? { |c| c.name == language }

    child = project.new(Xcodeproj::Project::Object::PBXFileReference)
    # name is the language, path is the file on disk: this pair is what makes
    # Xcode fold them into one row and what makes the build copy each into its
    # own .lproj inside the bundle.
    child.name = language
    child.path = File.join("#{language}.lproj", strings)
    child.source_tree = '<group>'
    child.last_known_file_type = 'text.plist.strings'
    variant << child
    changes << "added #{language} to #{strings}"
  end

  if resources.files_references.none? { |r| r.equal?(variant) || r.uuid == variant.uuid }
    resources.add_file_reference(variant)
    changes << "added #{strings} to Resources"
  end

  # Xcode will not build a localisation whose region it does not know about.
  languages.each do |language|
    next if project.root_object.known_regions.include?(language)

    project.root_object.known_regions << language
    changes << "added #{language} to knownRegions"
  end

  report(app, changes, project, project_path)
end

def report(app, changes, project, _project_path)
  if changes.empty?
    puts "#{app}: already carries all of it"
  else
    project.save
    puts "#{app}:"
    changes.each { |c| puts "  #{c}" }
  end
end

repo = File.expand_path('..', __dir__)
apps = ARGV.empty? ? Dir.children(File.join(repo, 'apps')).sort : ARGV

apps.each do |app|
  wire(File.join(repo, 'apps', app), app)
end

