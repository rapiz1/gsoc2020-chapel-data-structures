module Vector {
  record vector {
    param parSafe = false;
    type eltType;
    var capacity: int;

    proc init(type eltType) {
      this.eltType = eltType;
    }
    proc init=(other: vector(this.type.eltType)) {
      this.eltType = this.type.eltType;
    }
    proc init=(other: [?d] this.type.eltType) {
      this.eltType = this.type.eltType;
    }
    proc init=(other: list(this.type.eltType)) {
      this.eltType = this.type.eltType;
    }

    /*
      Insert an element at a given position

      :returns: if succeed
    */
    proc insert(idx: int, in x:eltType): bool {}

    /*
      Erase an element at a give position
    */
    proc erase(pos: int) {}

    /*
      Request a change in capacity
    */
    proc reserve(size: int) {}

    /*
      Pop the element at the end
    */
    proc pop(): eltType {}

    /*
      Append an element at the end
    */
    proc push(in x: eltType) {}

    /*
      Returns a new DefaultRectangular array containing a copy of each of the elements contained in this vector.
    */
    proc toArray(): [] eltType {}

    iter these() ref {}
  }
}
