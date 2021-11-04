attributes: nixpkgs: self: super:
super // {
  users = super.users ++ [attributes];
}
