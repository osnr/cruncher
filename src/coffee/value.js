window.Cruncher = Cr = window.Cruncher || {};

Cr.OverDeterminedException = class OverDeterminedException {};

Cr.UnderDeterminedException = class UnderDeterminedException {};

Cr.SolveException = class SolveException {};

Cr.Equation = class Equation {
  constructor(left, right) {
    this.solve = this.solve.bind(this);
    this.left = left;
    this.right = right;
    this.values = this.left.values.concat(this.right.values);
  }

  substitute(oldValue, newNum) {
    let newValue = new Cr.Value(newNum);
    return new Cr.Equation(
      this.left.substitute(oldValue, newValue),
      this.right.substitute(oldValue, newValue)
    );
  }

  solve() {
    // returns [free value, solution]
    let freeValues = Array.from(this.values)
      .filter(value => typeof value.num === "function")
      .map(value => value);

    if ((freeValues != null ? freeValues.length : undefined) < 1) {
      throw new Cr.OverDeterminedException();
    } else if ((freeValues != null ? freeValues.length : undefined) === 1) {
      let [leftF, rightF] = Array.from(
        [this.left, this.right].map(side =>
          (function(side) {
            if (typeof side.num === "function") {
              return side.num;
            } else {
              return x => side.num;
            }
          })(side)
        )
      );

      try {
        let solution = Cr.findRoot(x => leftF(x) - rightF(x), -1, 1);
        return [freeValues[0], solution];
      } catch (e) {
        console.log(e.stack);
        throw new Cr.SolveException();
      }
    } else {
      throw new Cr.UnderDeterminedException();
    }
  }
};

(function() {
  let doBaseOp = undefined;
  let doOp = undefined;
  let Cls = (Cr.Expression = class Expression {
    static initClass() {
      doBaseOp = function(op, left, right) {
        switch (op) {
          case "PLUS":
            return left + right;
          case "MINUS":
            return left - right;
          case "DIV":
            return left / right;
          case "MUL":
            return left * right;
          case "POW":
            return Math.pow(left, right);
        }
      };

      doOp = function(op, left, right) {
        if (typeof left === "number") {
          if (typeof right === "number") {
            // left and right both numbers
            return doBaseOp(op, left, right);
          } else if (typeof right === "function") {
            // left number, right free
            return x => doOp(op, left, right(x));
          }
        } else if (typeof left === "function") {
          if (typeof right === "number") {
            // left free, right number
            return x => doOp(op, left(x), right);
          } else if (typeof right === "function") {
            // left free, right free
            return x => y => doOp(op, left(x), right(y));
          }
        }
      };
    }
    constructor(value, ops) {
      this.values = [value];
      this.num = value.num;
      this.ops = [];

      if (ops == null) {
        ops = [];
      }
      for (let [op, other] of Array.from(ops)) {
        this.op(op, other);
      }
    }

    substitute(oldValue, newValue) {
      if (this.values[0] === oldValue) {
        return new Cr.Expression(newValue, this.ops);
      } else {
        let newOps = (() => {
          let result = [];
          for (let [op, other] of Array.from(this.ops)) {
            result.push([op, other.substitute(oldValue, newValue)]);
          }
          return result;
        })();
        return new Cr.Expression(this.values[0], newOps);
      }
    }

    op(op, other) {
      this.ops.push([op, other]);

      this.num = doOp(op, this.num, other.num);
      this.values = this.values.concat(other.values);

      return this;
    }

    numString() {
      // error if free number expression
      return this.num.toString();
    }
  });
  Cls.initClass();
  return Cls;
})();

Cr.Value = class Value {
  constructor(num) {
    this.num = num;
    if (this.num == null) {
      // free number
      this.num = x => x;
    }
  }

  neg() {
    this.num *= -1;
    return this;
  }

  setLocation(start, end) {
    this.start = start;
    this.end = end;
    return this;
  }

  numString() {
    // error if free number
    return this.num.toString();
  }
};
