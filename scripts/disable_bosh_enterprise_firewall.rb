#!/usr/bin/env ruby
$: << './lib'
require 'bundler/setup'
require 'machete'

Machete.logger.info '----> Enterprise firewall emulation for bosh'
Machete.logger.info '----> Enabling firewall'

Machete::Firewall.restore_iptables

