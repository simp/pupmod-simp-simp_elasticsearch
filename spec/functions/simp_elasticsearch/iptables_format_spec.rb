require 'spec_helper'

describe 'simp_elasticsearch::iptables_format' do
  context 'with valid input' do
    it { 
      is_expected.to run.with_params('es1:9210').and_return(
        '-s es1 -p tcp -m state --state NEW -m tcp -m multiport --dports 9210 -j ACCEPT')
    }

    it { 
      is_expected.to run.with_params(['es1:9210', '[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:1234']).and_return(
        "-s es1 -p tcp -m state --state NEW -m tcp -m multiport --dports 9210 -j ACCEPT\n" +
        '-s 2001:0db8:85a3:0000:0000:8a2e:0370:7334 -p tcp -m state --state NEW -m tcp -m multiport --dports 1234 -j ACCEPT')
    }
  end

  context 'with invalid input' do
    it { is_expected.to run.with_params('es1').and_raise_error(/'es1' missing a valid port/) }
    it { is_expected.to run.with_params('2001:0db8:85a3:0000:0000:8a2e:0370:7334').and_raise_error(/'2001:0db8:85a3:0000:0000:8a2e:0370:7334' missing a valid port/) }
    it { is_expected.to run.with_params('[2001:0db8:85a3:0000:0000:8a2e:0370:7334]').and_raise_error(/'\[2001:0db8:85a3:0000:0000:8a2e:0370:7334\]' missing a valid port/) }
    it { is_expected.to run.with_params('es1:').and_raise_error(/'es1:' missing a valid port/) }
    it { is_expected.to run.with_params('es1:oops').and_raise_error(/'es1:oops' missing a valid port/) }
    it { is_expected.to run.with_params('300.2.3.4:1234').and_raise_error(/'300.2.3.4' is not a valid network/) }
    it { is_expected.to run.with_params(1).and_raise_error(ArgumentError) }
  end
end

