_ = require 'underscore'

defaultAuth = (targetProperty) -> (user) ->
  if user?.id then  _.object([[targetProperty || 'user', user.id]]) else null



module.exports =
  users:
    auth: defaultAuth('id')
    authWrite: defaultAuth('id')
    authCreate: -> {}
    owners: {}
    fields:
      email: { type: 'string', required: true, unique: true }
      name: 'string'

  accounts:
    auth: defaultAuth()
    owners: user: 'users'
    defaultSort: 'name'
    fields:
      name: 'string'
      position: 'number'

  transactions:
    auth: defaultAuth()
    owners: user: 'users'
    defaultSort: 'date'
    fields:
      name: 'string'
      comment: 'string'
      date: 'date'
      position: 'number'
      sourceIdentifier: 'string' # används för importerade transactions, för att kunna upptäcka att en tidigare importerad redan finns i systemet

  # hade varit mer optimalt att ha två "owners"
  entries:
    auth: defaultAuth()
    owners: transaction: 'transactions'
    defaultSort: 'transaction' # funkar detta? att ha en owner som sort? det borde göra det...
    fields:
      value: 'number'
      position: 'number'
      account:
        type: 'hasOne'
        model: 'accounts'
        validation: (a, b, callback) ->
          if a.user.toString() != b.user.toString()
            callback('The account does not belong to the same user as the transaction')
          else
            callback()

  tags:
    auth: defaultAuth()
    owners: account: 'accounts'
    defaultSort: 'name'
    fields:
      name: 'string'
      factor: 'number'
