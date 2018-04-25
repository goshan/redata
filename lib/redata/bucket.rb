module Redata
  class S3Bucket
    def initialize
      s3 = Aws::S3::Resource.new
      @bucket = s3.bucket RED.s3['bucket']
    end

    def move(source, target)
      from = @bucket.object source
      to = @bucket.object target
      from.move_to to if from.exists?
    end

    def exist?(file)
      @bucket.object(file).exists?
    end

    def delete(file)
      @bucket.object(file).delete if exist?(file)
    end

    def make_public(file, is_public)
      acl = is_public ? 'public-read' : 'private'
      @bucket.object(file).acl.put({:acl => acl}) if exist?(file)
    end
  end
end
