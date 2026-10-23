'use strict';

function hasRole(profile, role) {
  return (
    !profile?.accountSuspended &&
    (profile?.role === role || (Array.isArray(profile?.roles) && profile.roles.includes(role)))
  );
}

module.exports = { hasRole };
