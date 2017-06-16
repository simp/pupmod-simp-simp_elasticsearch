require 'spec_helper'

describe 'simp_elasticsearch::systemd_escape' do
  testcases = {
    'hello, world'    => 'hello\x2c\x20world',
    '/some/file/path' => '-some-file-path',
    'a/b'             => 'a-b',
    'my-cluster'      => 'my\x2dcluster',
    'your_cluster'    => 'your_cluster',
    'their.cluster'   => 'their.cluster',
    'odd@!#$%&()*+,\/:;<=>?[]^{}|\~' =>
      'odd\x40\x21\x23\x24\x25\x26\x28\x29\x2a\x2b\x2c\x5c-:\x3b\x3c\x3d\x3e\x3f\x5b\x5d\x5e\x7b\x7d\x7c\x5c\x7e'
  }

  context 'with valid input' do
    testcases.each do |input, expected_output|
      it { is_expected.to run.with_params(input).and_return(expected_output) }
    end
  end

  context 'with invalid input' do
    it { is_expected.to run.with_params().and_raise_error(ArgumentError) }
    it { is_expected.to run.with_params(1).and_raise_error(ArgumentError) }
  end
end

