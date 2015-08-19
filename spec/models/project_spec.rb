require 'spec_helper'
include Models::RepositoryHelpers
include FileHelper

describe Project do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }

  it 'has a valid factory' do
    expect(create(:project)).to be_valid
  end

  it 'is invalid without a name' do
    expect(build(:project, name: '')).to_not be_valid
  end

  it 'is invalid without a user' do
    expect(build(:project, user: nil)).to_not be_valid
  end

  it 'has a unique name per user' do
    project = FactoryGirl.create(:project)
    expect(build(:project, user: project.user)).to_not be_valid
  end

  it 'allows same name for different users' do
    expect(build(:project, user: user)).to be_valid
  end

  it 'allows same name per user after the first is deleted' do
    project.destroy
    expect(build(:project, user: user)).to be_valid
  end

  it 'is soft deleted' do
    project = create(:project)
    expect {project.destroy}.to change {Project.count}
    expect {project.destroy}.not_to change{Project.with_deleted.count}
  end

  it 'sets path after creation' do
    expect(project.data_path).to_not eq(nil)
  end

  it 'creates repositories after creation' do
    expect(File.exists?(project.data_path)).to be true
    expect(Rugged::Repository.new("#{project.data_path}" + '.git'))
      .to be_a(Rugged::Repository)
    expect(Rugged::Repository.new(File.join(
      project.data_path,
      'satellite',
      '.git'
    ))).to be_a(Rugged::Repository)
  end

  it 'gets list of inspiring projects' do
    create(:project, name: 't2', private: true, user: project.user)
    expect(Project.inspiring_projects_for(project.user.id).count).to eq(0)
    expect(Project.inspiring_projects_for(project.user.id + 1).count).to eq(1)
  end

  it 'gets thumbnails path' do
    commit_id = SecureRandom.hex(20)
    real_path = "/testdata/repos/#{project.user.username}/#{project.name}/" \
                "thumbnails/#{commit_id}"
    expect(project.image_for(commit_id, 'thumbnails', false)).to eq(real_path)
    real_path = 'public' + real_path
    expect(project.image_for(commit_id, 'thumbnails', true)).to eq(real_path)
  end

  describe 'inspire images' do
    before { add_image project, 'happypanda.png' }

    it 'gets desktop images path' do
      real_path = "/testdata/repos/#{project.user.username}/#{project.name}/"\
                  'inspire/desktop/happypanda.png'
      expect(project.image_for('happypanda.png', 'desktop_inspire', false))
        .to eq(real_path)
    end

    it 'gets mobie images path' do
      real_path = "/testdata/repos/#{project.user.username}/#{project.name}/"\
                  'inspire/mobile/happypanda.png'
      expect(project.image_for('happypanda.png', 'mobile_inspire', false))
        .to eq(real_path)
    end

    it 'generates mobile and desktop images' do
      desk_p = "public/testdata/repos/#{project.user.username}/"\
             "#{project.name}/inspire/desktop/happypanda.png"
      mob_p = "public/testdata/repos/#{project.user.username}/"\
             "#{project.name}/inspire/mobile/happypanda.png"
      expect(File).to exist(desk_p)
      expect(File).to exist(mob_p)
    end
  end

  describe '#urlbase' do
    it 'is correct' do
      expect(project.urlbase).to eq("/#{project.user.username}/#{project.name}")
    end

    it 'handles spaces properly' do
      project = create(:project, name: 'test project', user: user)
      expect(project.urlbase).to eq("/#{user.username}/test%20project")
    end
  end

  describe '#barerepo' do
    it 'is a valid repository' do
      expect(project.barerepo).to be_a(Rugged::Repository)
    end
  end

  describe '#satelliterepo' do
    it 'is a valid repository' do
      expect(project.satelliterepo).to be_a(Rugged::Repository)
    end
  end

  describe '#tree' do
    context 'empty repo' do
      it 'returns false' do
        expect(project.tree).to eq(false)
      end
    end

    context 'nonempty repo' do
      before :each do
        initialize_dummy_repo project
      end

      it 'returns false for invalid tree id' do
        expect(project.tree('1a')).to eq(false)
      end

      it 'returns false for wrong tree id' do
        expect(project.tree('4eee8aa0ea3fc32a0f3a9de626423ec0f2a4b39a'))
          .to eq(false)
      end

      it 'returns tree object for correct tree id' do
        expect(project.tree('4eee8aa0ea3fc32a0f3a9de626423ec0f2a4b39f').type)
          .to eq(:tree)
      end
    end
  end

  describe '#commit' do
    context 'empty repo' do
      it 'returns false' do
        expect(project.commit).to eq(false)
      end
    end

    context 'nonempty repo' do
      before :each do
        initialize_dummy_repo project
      end

      it 'returns false for invalid commit id' do
        expect(project.commit('1a')).to eq(false)
      end

      it 'returns false for a tree id' do
        expect(project.commit('4eee8aa0ea3fc32a0f3a9de626423ec0f2a4b39f'))
          .to eq(false)
      end

      it 'returns tree object for correct commit id' do
        expect(project.commit('16047dfc3ba3b4a8a6244dec410c0338b305a3ed').type)
          .to eq(:commit)
      end
    end
  end

  describe '#blob' do
    before { initialize_dummy_repo project }

    it 'is falsey for invalid data' do
      expect(project.blob('4', '1.png')).to be_falsey
      expect(project.blob('16047dfc3ba3b4a8a6244dec410c0338b305a3ed', '453'))
        .to be_falsey
    end

    it 'returns a blob for valid data' do
      expect(project.blob('16047dfc3ba3b4a8a6244dec410c0338b305a3ed', '1.png')
        .type).to eq(:blob)
    end
  end

  describe '#find_blob_data' do
    before { add_image project, 'happypanda.png' }

    it 'finds image data' do
      sha = project.barerepo.head.target.oid
      data = project.find_blob_data(sha, 'happypanda.png')
      expect(data.first[:name]). to eq('happypanda.png')
      expect(data.second.oid). to eq(sha)
    end
  end
end
