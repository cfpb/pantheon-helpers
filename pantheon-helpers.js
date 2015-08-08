(function() {
  // this code can only be used in couchdb.
  module.exports = {
    design_docs: {
      helpers: require('lib/pantheon-helpers-design-docs/helpers'),
    }
  };

}).call(this);
