/*
 * Copyright 2020 Hewlett Packard Enterprise Development LP
 * Copyright 2004-2019 Cray Inc.
 * Other additional copyright holders may be indicated within.
 *
 * The entirety of this work is licensed under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 *
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/*
  This module contains the implementation of the vector type.
*/
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
