$: << File.expand_path("..", __FILE__)
require 'cloud_foundry'

def dns_addr
  @dns_addr ||=
      with_vagrant_env { `vagrant ssh -c "sudo ip -f inet addr" 2>&1 | grep eth0 | grep inet`.split(" ")[1].gsub(/\d+\/\d+$/, "0/24") }
end

def action(*actions)
  actions.each do |action|
    CloudFoundry.logger.info "-----> #{action}"
  end
end

if ENV['VAGRANT_CWD']
  VAGRANT_CWD = ENV['VAGRANT_CWD']
else
  VAGRANT_CWD = "#{ENV['HOME']}/workspace/bosh-lite/"
  action "No VAGRANT_CWD, using default: #{ENV['VAGRANT_CWD']}"
end

def set_vagrant_working_directory
  # this is local to the clean env - thats why it seems strange that we set it often.
  ENV['VAGRANT_CWD'] = VAGRANT_CWD
end

def with_vagrant_env
  Bundler.with_clean_env do
    set_vagrant_working_directory
    yield
  end
end

def raw_warden_postrouting_rules
  output = with_vagrant_env do
    `vagrant ssh -c "sudo iptables -t nat -L warden-postrouting -v -n --line-numbers" 2>&1`.split("\n")
  end

  chains = output.drop 1
  keys = chains.shift.split(/\s+/).map { |key| key.to_sym }

  chains.map do |rule|
    key_values = keys.zip(rule.split(/\s+/))
    Hash[key_values]
  end
end

def select_default_masquerade_rules(rules)
  rules.select do |rule|
    rule[:target] == 'MASQUERADE' &&
        rule[:source] == '10.244.0.0/19' &&
        rule[:destination] == '!10.244.0.0/19'
  end
end

def select_dns_only_rules(rules)
  rules.select do |rule|
    rule[:target] == 'MASQUERADE' &&
        rule[:source] == '10.244.0.0/19' &&
        rule[:destination] == dns_addr
  end
end

def masquerade_dns_only
  raw_rules = raw_warden_postrouting_rules
  default_rules = select_default_masquerade_rules(raw_rules)

  if default_rules.empty?
    warn 'No default masquerading rules to remove'
  else
    remove_rule_commands = default_rules.sort_by { |rule| rule[:num] }.reverse.map do |rule|
      "sudo iptables -t nat -D warden-postrouting #{rule[:num]}"
    end.join("\n")

    action 'Removing matching rules: '
    CloudFoundry.logger.info remove_rule_commands

    with_vagrant_env do
      CloudFoundry.logger.info `vagrant ssh -c "#{remove_rule_commands}" 2>&1`
    end
  end

  dns_only_rules = select_dns_only_rules(raw_rules)

  if dns_only_rules.empty?
    action 'Adding DNS masquerading rule'
    with_vagrant_env do
      CloudFoundry.logger.info `vagrant ssh -c "sudo iptables -t nat -A warden-postrouting -s 10.244.0.0/19 -d #{dns_addr} -j MASQUERADE" 2>&1`
    end
  else
    warn 'dns-only warden-postrouting chain already exists'
  end

  CloudFoundry.logger.info raw_warden_postrouting_rules
end

def open_firewall_for_appdirect
  host = URI.parse(ENV['APPDIRECT_URL']).host
  `vagrant ssh -c "sudo iptables -t nat -A warden-postrouting -s 10.244.0.0/19 -d #{host} -j MASQUERADE " 2>&1`
end

def reinstate_default_masquerading_rules
  raw_rules = raw_warden_postrouting_rules
  default_rules = select_default_masquerade_rules(raw_rules)

  if default_rules.empty?
    action 'Reinstating rules: '
    with_vagrant_env do
      CloudFoundry.logger.info `vagrant ssh -c "sudo iptables -t nat -A warden-postrouting -s 10.244.0.0/19 ! -d 10.244.0.0/19 -j MASQUERADE" 2>&1`
    end
  else
    warn 'Masquerading rules already exist'
  end

  dns_only_rules = select_dns_only_rules(raw_rules)

  if dns_only_rules.empty?
    warn 'Could not find DNS masquerading rule'
  else
    action 'Removing DNS masquerading rule'
    with_vagrant_env do
      CloudFoundry.logger.info `vagrant ssh -c "sudo iptables -t nat -D warden-postrouting -s 10.244.0.0/19 -d #{dns_addr} -j MASQUERADE" 2>&1`
    end
  end

  CloudFoundry.logger.info raw_warden_postrouting_rules

end

