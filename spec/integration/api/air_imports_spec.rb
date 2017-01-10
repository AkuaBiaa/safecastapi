require 'spec_helper'

feature '/air_imports API endpoint', type: :request do
  before(:each) do
    User.destroy_all
    @user ||= Fabricate(:user)

    create_air_v0_station

    @result ||= api_post('/air_imports', {
      api_key: @user.authentication_token,
      air_import: { source: fixture_file_upload('/air0simple.log') }
    }, 'HTTP_ACCEPT' => 'application/json')
  end

  context 'just an upload' do
    scenario 'response should be unprocessed' do
      @result['id'].should_not be_blank
      @result['status'].should eq 'unprocessed'
      @result['md5sum'].should eq '55ae85eabd50cad18f5b2ee013912b7f'
    end
  end

  context 'after processing' do
    before(:each) do
      Delayed::Worker.new.work_off
      AirImport.find_each(&:finalize!)
    end

    let!(:updated_result) do
      api_get(
        "/air_imports/#{@result['id']}",
        {},
        'HTTP_ACCEPT' => 'application/json'
      )
    end

    subject { updated_result }

    scenario 'response should be processed' do
      updated_result['status'].should == 'done'
    end

    scenario 'it should have imported a measurements for each value' do
      updated_result['measurements_count'].should == 53
    end
  end
end
