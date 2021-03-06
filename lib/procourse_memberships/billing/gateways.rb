module ProcourseMemberships
  module Billing
    class Gateways

      def initialize(options = {})
        @options = options
      end

      def self.mode
        SiteSetting.memberships_go_live ? :production : :test
      end

      def self.test?
        !SiteSetting.memberships_go_live
      end

      def self.name
        SiteSetting.memberships_gateway.gsub(/\s+/, "").downcase
      end

      def gateway
        ProcourseMemberships::Gateways.const_get((SiteSetting.memberships_gateway + "Gateway").to_sym).new
      end

      def store_token
        tokens = PluginStore.get("procourse_memberships", "tokens:" + @options[:user_id].to_s) || []
        time = Time.now

        new_token = {
          product_id: @options[:product_id],
          token: @options[:token],
          created_at: time,
          updated_at: time
        }

        tokens.push(new_token)

        PluginStore.set("procourse_memberships", "tokens:" + @options[:user_id].to_s, tokens)
      end

      def update_token
        tokens = PluginStore.get("procourse_memberships", "tokens:" + @options[:user_id].to_s) || []

        token = tokens.select{|token| token[:product_id] == @options[:product_id]}

        time = Time.now

        unless token.empty?
          token[0][:token] = @options[:token]
          token[0][:updated_at] = time
        end

        PluginStore.set("procourse_memberships", "tokens:" + @options[:user_id].to_s, tokens)
      end

      def store_subscription(subscription_id, subscription_end_date)
        subscriptions = PluginStore.get("procourse_memberships", "s:" + @options[:user_id].to_s) || []
        log = PluginStore.get("procourse_memberships", "log") || []
        time = Time.now

        new_subscription = {
          product_id: @options[:product_id],
          subscription_id: subscription_id,
          subscription_end_date: subscription_end_date,
          active: true,
          created_at: time,
          updated_at: time
        }

        subscriptions.push(new_subscription)

        PluginStore.set("procourse_memberships", "s:" + @options[:user_id].to_s, subscriptions)

        # Add to admin transaction log
        username = User.find(@options[:user_id]).username

        new_log = {
          timestamp: time.strftime("%m/%d/%Y %I:%M%p %z"),
          username: username,
          level_id: @options[:product_id],
          type: "Subscription",
          amount: "---"
        }

        log.push(new_log)

        PluginStore.set("procourse_memberships", "log", log)
      end

      def store_transaction(transaction_id, transaction_amount, transaction_date, credit_card = {}, paypal = {})
        transactions = PluginStore.get("procourse_memberships", "t:" + @options[:user_id].to_s) || []
        log = PluginStore.get("procourse_memberships", "log") || []

        time = Time.now

        new_transaction = {
          product_id: @options[:product_id],
          transaction_id: transaction_id,
          transaction_amount: transaction_amount,
          transaction_date: transaction_date,
          created_at: time,
          credit_card: credit_card,
          paypal: paypal
        }

        transactions.push(new_transaction)

        PluginStore.set("procourse_memberships", "t:" + @options[:user_id].to_s, transactions)

        # Add to admin transaction log
        username = User.find(@options[:user_id]).username

        new_log = {
          timestamp: time.strftime("%m/%d/%Y %I:%M%p %z"),
          username: username,
          level_id: @options[:product_id],
          type: "Payment",
          amount: transaction_amount
        }

        log.push(new_log)

        PluginStore.set("procourse_memberships", "log", log)

        PostCreator.create(
          ProcourseMemberships.contact_user,
          target_usernames: username,
          archetype: Archetype.private_message,
          title: I18n.t('memberships.private_messages.receipt.title', {transactionId: transaction_id}),
          raw: I18n.t('memberships.private_messages.receipt.message')
        )
      end

      def unstore_subscription
        subscriptions = PluginStore.get("procourse_memberships", "s:" + @options[:user_id].to_s)
        subscription = subscriptions.select{|subscription| subscription[:product_id] = @options[:product_id].to_i}
        time = Time.now
        
        subscriptions.delete(subscription[0])
        PluginStore.set("procourse_memberships", "s:" + @options[:user_id].to_s, subscriptions)

        # Add to admin transaction log
        log = PluginStore.get("procourse_memberships", "log") || []
        username = User.find(@options[:user_id]).username
        new_log = {
          timestamp: time.strftime("%m/%d/%Y %I:%M%p %z"),
          username: username,
          level_id: @options[:product_id],
          type: "Cancellation",
          amount: "---"
        }

        log.push(new_log)

        PluginStore.set("procourse_memberships", "log", log)
      end
    end
  end
end

require_relative "../gateways/braintree"
require_relative "../gateways/paypal"
require_relative "../gateways/stripe"
