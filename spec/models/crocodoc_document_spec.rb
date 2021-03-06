#
# Copyright (C) 2012 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe 'CrocodocDocument' do
  before do
    Setting.set 'crocodoc_counter', 0
    PluginSetting.create! :name => 'crocodoc',
                          :settings => { :api_key => "blahblahblahblahblah" }
    Crocodoc::API.any_instance.stubs(:upload).returns 'uuid' => '1234567890'
  end

  context 'permissions_for_user' do
    before do
      teacher_in_course(:active_all => true)
      student_in_course
      @submitter = @student
      student_in_course
      @other_student = @student
      submission_model :course => @course, :user => @submitter
      attachment = attachment_model(:context => @submitter)
      attachment.associate_with(@submission)
      attachment.save!
      @crocodoc = attachment.create_crocodoc_document
    end

    it "should let the teacher view all annotations" do
      @crocodoc.permissions_for_user(@teacher).should == {
        :filter => 'all',
        :admin => true,
        :editable => true,
      }
    end

    context "submitter permissions" do
      it "should see everything (unless the assignment is muted)" do
        @crocodoc.permissions_for_user(@submitter).should == {
          :filter => 'all',
          :admin => false,
          :editable => true,
        }
      end

      it "should only see their own annotations when assignment is muted" do
        @assignment.mute!
        @crocodoc.permissions_for_user(@submitter).should == {
          :filter => @submitter.crocodoc_id,
          :admin => false,
          :editable => true,
        }
      end
    end

    it "should only allow classmates to see their own annotations" do
      @crocodoc.permissions_for_user(@other_student).should == {
        :filter => @other_student.crocodoc_id!,
        :admin => false,
        :editable => true,
      }
    end

    it "should not allow annotations if no user is given" do
      @crocodoc.permissions_for_user(nil).should == {
        :filter => 'none',
        :admin => false,
        :editable => false,
      }
    end
  end

  context 'update_process_states' do
    it "should honor the batch size setting" do
      Setting.set('crocodoc_status_check_batch_size', 2)
      4.times { CrocodocDocument.create!(:process_state => "QUEUED") }
      Crocodoc::API.any_instance.expects(:status).times(2).returns []
      CrocodocDocument.update_process_states
    end
  end
end
