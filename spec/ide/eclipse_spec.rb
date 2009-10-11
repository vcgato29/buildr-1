# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.


require File.join(File.dirname(__FILE__), '../spec_helpers')


JAVA_CONTAINER   = Buildr::Eclipse::Java::CONTAINER
SCALA_CONTAINER  = Buildr::Eclipse::Scala::CONTAINER
PLUGIN_CONTAINER = Buildr::Eclipse::Plugin::CONTAINER

JAVA_NATURE   = Buildr::Eclipse::Java::NATURE
SCALA_NATURE  = Buildr::Eclipse::Scala::NATURE
PLUGIN_NATURE = Buildr::Eclipse::Plugin::NATURE

JAVA_BUILDER    = Buildr::Eclipse::Java::BUILDER
SCALA_BUILDER   = Buildr::Eclipse::Scala::BUILDER
PLUGIN_BUILDERS = Buildr::Eclipse::Plugin::BUILDERS


module EclipseHelper
  def classpath_xml_elements
    task('eclipse').invoke
    REXML::Document.new(File.open('.classpath')).root.elements
  end

  def classpath_sources(attribute='path')
    classpath_xml_elements.collect("classpathentry[@kind='src']") { |n| n.attributes[attribute] }
  end

  # <classpathentry path="PATH" output="RETURNED_VALUE"/>
  def classpath_specific_output(path)
    specific_output = classpath_xml_elements.collect("classpathentry[@path='#{path}']") { |n| n.attributes['output'] }
    raise "expected: one output attribute for path '#{path}, got: #{specific_output.inspect}" if specific_output.length > 1
    specific_output[0]
  end

  # <classpathentry path="RETURNED_VALUE" kind="output"/>
  def classpath_default_output
    default_output = classpath_xml_elements.collect("classpathentry[@kind='output']") { |n| n.attributes['path'] }
    raise "expected: one path attribute for kind='output', got: #{default_output.inspect}" if default_output.length > 1
    default_output[0]
  end

  # <classpathentry path="PATH" sourcepath="RETURNED_VALUE" kind="var"/>
  def sourcepath_for_path(path)
    classpath_xml_elements.collect("classpathentry[@kind='var',@path='#{path}']") do |n|
      n.attributes['sourcepath'] || 'no source artifact'
    end
  end

  def project_xml_elements
    task('eclipse').invoke
    REXML::Document.new(File.open('.project')).root.elements
  end

  def project_natures
    project_xml_elements.collect("natures/nature") { |n| n.text }
  end

  def build_commands
    project_xml_elements.collect("buildSpec/buildCommand/name") { |n| n.text }
  end

  def classpath_containers(attribute='path')
    classpath_xml_elements.collect("classpathentry[@kind='con']") { |n| n.attributes[attribute] }
  end
end


describe Buildr::Eclipse do
  include EclipseHelper

  describe "eclipse's .project file" do

    describe 'java project' do
      before do
        write 'buildfile'
        write 'src/main/java/Main.java'
      end

      it 'should have Java nature' do
        define('foo')
        project_natures.should include(JAVA_NATURE)
      end

      it 'should have Java build command' do
        define('foo')
        build_commands.should include(JAVA_BUILDER)
      end
    end

    describe 'nested java project' do

      it 'should have name corresponding to its project definition' do
        mkdir 'foo'
        define('myproject') {
          project.version = '1.0'
          define('foo') { compile.using(:javac); package :jar }
        }
        task('eclipse').invoke
        REXML::Document.new(File.open(File.join('foo', '.project'))).root.
          elements.collect("name") { |e| e.text }.should == ['myproject-foo']
      end

    end

    describe 'scala project' do

      before do
        define 'foo' do
          eclipse.natures :scala
        end
      end

      it 'should have Scala nature before Java nature' do
        project_natures.should include(SCALA_NATURE)
        project_natures.should include(JAVA_NATURE)
        project_natures.index(SCALA_NATURE).should < project_natures.index(JAVA_NATURE)
      end

      it 'should have Scala build command and no Java build command' do
        build_commands.should include(SCALA_BUILDER)
        build_commands.should_not include(JAVA_BUILDER)
      end
    end

    describe 'standard scala project' do

      before do
        write 'buildfile'
        write 'src/main/scala/Main.scala'
        define 'foo'
      end

      it 'should have Scala nature before Java nature' do
        project_natures.should include(SCALA_NATURE)
        project_natures.should include(JAVA_NATURE)
        project_natures.index(SCALA_NATURE).should < project_natures.index(JAVA_NATURE)
      end

      it 'should have Scala build command and no Java build command' do
        build_commands.should include(SCALA_BUILDER)
        build_commands.should_not include(JAVA_BUILDER)
      end
    end

    describe 'non-standard scala project' do

      before do
        write 'buildfile'
        write 'src/main/foo/Main.scala'
        define 'foo' do
          eclipse.natures = :scala
        end
      end

      it 'should have Scala nature before Java nature' do
        project_natures.should include(SCALA_NATURE)
        project_natures.should include(JAVA_NATURE)
        project_natures.index(SCALA_NATURE).should < project_natures.index(JAVA_NATURE)
      end

      it 'should have Scala build command and no Java build command' do
        build_commands.should include(SCALA_BUILDER)
        build_commands.should_not include(JAVA_BUILDER)
      end
    end

    describe 'Plugin project' do

      before do
        write 'buildfile'
        write 'src/main/java/Activator.java'
        write 'plugin.xml'
      end

      it 'should have plugin nature before Java nature' do
        define('foo')
        project_natures.should include(PLUGIN_NATURE)
        project_natures.should include(JAVA_NATURE)
        project_natures.index(PLUGIN_NATURE).should < project_natures.index(JAVA_NATURE)
      end

      it 'should have plugin build commands and the Java build command' do
        define('foo')
        build_commands.should include(PLUGIN_BUILDERS[0])
        build_commands.should include(PLUGIN_BUILDERS[1])
        build_commands.should include(JAVA_BUILDER)
      end
    end
    
    describe 'Non standard Plugin project' do

      before do
        write 'buildfile'
        write 'src/main/java/Activator.java'
        write 'plugin.xml'
      end

      it 'should have plugin nature before Java nature' do
        define('foo') do
          eclipse.natures = [:java, :plugin]
        end
        project_natures.should include(PLUGIN_NATURE)
        project_natures.should include(JAVA_NATURE)
        project_natures.index(PLUGIN_NATURE).should < project_natures.index(JAVA_NATURE)
      end

      it 'should have plugin build commands and the Java build command' do
        define('foo') do
          eclipse.natures = [:java, :plugin]
        end
        build_commands.should include(PLUGIN_BUILDERS[0])
        build_commands.should include(PLUGIN_BUILDERS[1])
        build_commands.should include(JAVA_BUILDER)
      end
    end
  end

  describe "eclipse's .classpath file" do

    describe 'scala project' do

      before do
        write 'buildfile'
        write 'src/main/scala/Main.scala'
      end

      it 'should have SCALA_CONTAINER before JAVA_CONTAINER' do
        define('foo')
        classpath_containers.should include(SCALA_CONTAINER)
        classpath_containers.should include(JAVA_CONTAINER)
        classpath_containers.index(SCALA_CONTAINER).should < classpath_containers.index(JAVA_CONTAINER)
      end
    end

    describe 'source folders' do

      before do
        write 'buildfile'
        write 'src/main/java/Main.java'
        write 'src/test/java/Test.java'
      end

      describe 'source', :shared=>true do
        it 'should ignore CVS and SVN files' do
          define('foo')
          classpath_sources('excluding').each do |excluding_attribute|
            excluding = excluding_attribute.split('|')
            excluding.should include('**/.svn/')
            excluding.should include('**/CVS/')
          end
        end
      end

      describe 'main code' do
        it_should_behave_like 'source'

        it 'should accept to come from the default directory' do
          define('foo')
          classpath_sources.should include('src/main/java')
        end

        it 'should accept to come from a user-defined directory' do
          define('foo') { compile path_to('src/java') }
          classpath_sources.should include('src/java')
        end

        it 'should accept a file task as a main source folder' do
          define('foo') { compile apt }
          classpath_sources.should include('target/generated/apt')
        end

        it 'should go to the default target directory' do
          define('foo')
          classpath_specific_output('src/main/java').should be(nil)
          classpath_default_output.should == 'target/classes'
        end
      end

      describe 'test code' do
        it_should_behave_like 'source'

        it 'should accept to come from the default directory' do
          define('foo')
          classpath_sources.should include('src/test/java')
        end

        it 'should accept to come from a user-defined directory' do
          define('foo') { test.compile path_to('src/test') }
          classpath_sources.should include('src/test')
        end

        it 'should go to the default target directory' do
          define('foo')
          classpath_specific_output('src/test/java').should == 'target/test/classes'
        end

        it 'should accept to be the only code in the project' do
          rm 'src/main/java/Main.java'
          define('foo')
          classpath_sources.should include('src/test/java')
        end
      end

      describe 'main resources' do
        it_should_behave_like 'source'

        before do
          write 'src/main/resources/config.xml'
        end

        it 'should accept to come from the default directory' do
          define('foo')
          classpath_sources.should include('src/main/resources')
        end

        it 'should share a classpath entry if it comes from a directory with code' do
          write 'src/main/java/config.properties'
          define('foo') { resources.from('src/main/java').exclude('**/*.java') }
          classpath_sources.select { |path| path == 'src/main/java'}.length.should == 1
        end

        it 'should go to the default target directory' do
          define('foo')
          classpath_specific_output('src/main/resources').should == 'target/resources'
        end
      end

      describe 'test resources' do
        it_should_behave_like 'source'

        before do
          write 'src/test/resources/config-test.xml'
        end

        it 'should accept to come from the default directory' do
          define('foo')
          classpath_sources.should include('src/test/resources')
        end

        it 'should share a classpath entry if it comes from a directory with code' do
          write 'src/test/java/config-test.properties'
          define('foo') { test.resources.from('src/test/java').exclude('**/*.java') }
          classpath_sources.select { |path| path == 'src/test/java'}.length.should == 1
        end

        it 'should go to the default target directory' do
          define('foo')
          classpath_specific_output('src/test/resources').should == 'target/test/resources'
        end
      end
    end

    describe 'project depending on another project' do
      it 'should have the underlying project in its classpath' do
        mkdir 'foo'
        mkdir 'bar'
        define('myproject') {
          project.version = '1.0'
          define('foo') { package :jar }
          define('bar') { compile.using(:javac).with project('foo'); }
        }
        task('eclipse').invoke
        REXML::Document.new(File.open(File.join('bar', '.classpath'))).root.
          elements.collect("classpathentry[@kind='src']") { |n| n.attributes['path'] }.should include('/myproject-foo')
      end
    end
  end

  describe 'local dependency' do
    before do
      write 'lib/some-local.jar'
      define('foo') { compile.using(:javac).with(_('lib/some-local.jar')) }
    end
    
    it 'should have a lib artifact reference in the .classpath file' do
      classpath_xml_elements.collect("classpathentry[@kind='lib']") { |n| n.attributes['path'] }.
        should include(File.expand_path 'lib/some-local.jar')
    end
  end

  describe 'generated .classes' do
    before do
      write 'lib/some.class'
      define('foo') { compile.using(:javac).with(_('lib')) }
    end
    
    it 'should have src reference in the .classpath file' do
      classpath_xml_elements.collect("classpathentry[@kind='src']") { |n| n.attributes['path'] }.
        should include('lib')
    end
  end

  describe 'maven2 artifact dependency' do
    before do
      define('foo') { compile.using(:javac).with('com.example:library:jar:2.0') }
      artifact('com.example:library:jar:2.0') { |task| write task.name }
      task('eclipse').invoke
    end

    it 'should have a reference in the .classpath file relative to the local M2 repo' do
      classpath_xml_elements.collect("classpathentry[@kind='var']") { |n| n.attributes['path'] }.
        should include('M2_REPO/com/example/library/2.0/library-2.0.jar')
    end

    it 'should be downloaded' do
      file(artifact('com.example:library:jar:2.0').name).should exist
    end

    it 'should have a source artifact reference in the .classpath file' do
      sourcepath_for_path('M2_REPO/com/example/library/2.0/library-2.0.jar').
        should == ['M2_REPO/com/example/library/2.0/library-2.0-sources.jar']
    end
  end

  describe 'maven2 repository variable' do
    it 'should be configurable' do
      define('foo') do
        eclipse.options.m2_repo_var = 'PROJ_REPO'
        compile.using(:javac).with('com.example:library:jar:2.0')
      end
      artifact('com.example:library:jar:2.0') { |task| write task.name }

      task('eclipse').invoke
      classpath_xml_elements.collect("classpathentry[@kind='var']") { |n| n.attributes['path'] }.
        should include('PROJ_REPO/com/example/library/2.0/library-2.0.jar')
    end

    it 'should pick the parent value by default' do
      define('foo') do
        eclipse.options.m2_repo_var = 'FOO_REPO'
        define('bar')

        define('bar2') do
          eclipse.options.m2_repo_var = 'BAR2_REPO'
        end
      end
      project('foo:bar').eclipse.options.m2_repo_var.should eql('FOO_REPO')
      project('foo:bar2').eclipse.options.m2_repo_var.should eql('BAR2_REPO')
    end
  end

  describe 'natures variable' do
    it 'should be configurable' do
      define('foo') do
        eclipse.natures = 'dummyNature'
        compile.using(:javac).with('com.example:library:jar:2.0')
      end
      artifact('com.example:library:jar:2.0') { |task| write task.name }
      project_natures.should include('dummyNature')
    end

    it 'should pick the parent value by default' do
      define('foo') do
        eclipse.natures = 'foo_nature'
        define('bar')

        define('bar2') do
          eclipse.natures = 'bar2_nature'
        end
      end
      project('foo:bar').eclipse.natures.should include('foo_nature')
      project('foo:bar2').eclipse.natures.should include('bar2_nature')
    end
  end

  describe 'builders variable' do
    it 'should be configurable' do
      define('foo') do
        eclipse.builders 'dummyBuilder'
        compile.using(:javac).with('com.example:library:jar:2.0')
      end
      artifact('com.example:library:jar:2.0') { |task| write task.name }
      build_commands.should include('dummyBuilder')
    end

    it 'should pick the parent value by default' do
      define('foo') do
        eclipse.builders = 'foo_builder'
        define('bar')

        define('bar2') do
          eclipse.builders = 'bar2_builder'
        end
      end
      project('foo:bar').eclipse.builders.should include('foo_builder')
      project('foo:bar2').eclipse.builders.should include('bar2_builder')
    end
  end

  describe 'classpath_containers variable' do
    it 'should be configurable' do
      define('foo') do
        eclipse.classpath_containers = 'myOlGoodContainer'
        compile.using(:javac).with('com.example:library:jar:2.0')
      end
      artifact('com.example:library:jar:2.0') { |task| write task.name }
      classpath_containers.should include('myOlGoodContainer')
    end

    it 'should pick the parent value by default' do
      define('foo') do
        eclipse.classpath_containers = 'foo_classpath_containers'
        define('bar')

        define('bar2') do
          eclipse.classpath_containers = 'bar2_classpath_containers'
        end
      end
      project('foo:bar').eclipse.classpath_containers.should include('foo_classpath_containers')
      project('foo:bar2').eclipse.classpath_containers.should include('bar2_classpath_containers')
    end
  end
end
