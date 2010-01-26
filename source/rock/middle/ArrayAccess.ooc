import structs/[ArrayList]
import ../frontend/[Token, BuildParams]
import Visitor, Expression, VariableDecl, Declaration, Type, Node,
       OperatorDecl, FunctionCall, Import, Module, BinaryOp
import tinker/[Resolver, Response, Trail]

ArrayAccess: class extends Expression {

    array, index: Expression
    type: Type = null
    
    getArray: func -> Expression { array }
    getIndex: func -> Expression { index }
    
    init: func ~arrayAccess (=array, =index, .token) {
        super(token)
    }
    
    accept: func (visitor: Visitor) {
        visitor visitArrayAccess(this)
    }
    
    resolve: func (trail: Trail, res: Resolver) -> Response {
        
        if(!index resolve(trail, res) ok()) {
            //printf("Whole-again because of index!\n")
            res wholeAgain(this, "because of index!")
        }
        if(!array resolve(trail, res) ok()) {
            //printf("Whole-again because of array!\n")
            res wholeAgain(this, "because of array!")
        }
        
        if(array getType() == null) {
            //printf("Whole-again because of array type!\n")
            res wholeAgain(this, "because of array type!")
        } else {
            type = array getType() dereference()
        }
        
        {
            response := resolveOverload(trail, res)
            if(!response ok()) return response
        }
        
        return Responses OK
        
    }
    
    resolveOverload: func (trail: Trail, res: Resolver) -> Response {
        
        // so here's the plan: we give each operator overload a score
        // depending on how well it fits our requirements (types)
        
        bestScore := 0
        candidate : OperatorDecl = null
        
        parent := trail peek()
        reqType := parent getRequiredType()
        
        inAssign := (parent instanceOf(BinaryOp)) &&
                    (parent as BinaryOp isAssign()) &&
                    (parent as BinaryOp getLeft() == this)
        
        for(opDecl in trail module() getOperators()) {
            score := getScore(opDecl, reqType, inAssign)
            if(score > bestScore) {
                bestScore = score
                candidate = opDecl
            }
        }
        
        for(imp in trail module() getImports()) {
            module := imp getModule()
            for(opDecl in module getOperators()) {
                score := getScore(opDecl, reqType, inAssign)
                if(score > bestScore) {
                    bestScore = score
                    candidate = opDecl
                }
            }
        }
        
        if(candidate != null) {
            fDecl := candidate getFunctionDecl()
            fCall := FunctionCall new(fDecl getName(), token)
            fCall setRef(fDecl)
            fCall getArguments() add(array)
            fCall getArguments() add(index)
            
            if(inAssign) {
                assign := parent as BinaryOp
                fCall getArguments() add(assign getRight())
                
                if(!trail peek(2) replace(assign, fCall)) {
                    token throwError("Couldn't replace %s with %s!" format(toString(), fCall toString()))
                }
            } else {
                if(!trail peek() replace(this, fCall)) {
                    token throwError("Couldn't replace %s with %s!" format(toString(), fCall toString()))
                }
            }
            
            res wholeAgain(this, "Just been replaced with an overload")
        }
        
        return Responses OK
        
    }
    
    getScore: func (op: OperatorDecl, reqType: Type, inAssign: Bool) -> Int {
        
        if(!(op getSymbol() equals(inAssign ? "[]=" : "[]"))) {
            return 0 // not the right overload type - skip
        }
        
        fDecl := op getFunctionDecl()
        
        args := fDecl getArguments()
        /*
        if(args size() != 2) {
            op token throwError(
                "Argl, you need 2 arguments to override the '%s' operator, not %d" format(symbol, args size()))
        }
        */
        
        score := 0
        
        score += args get(0) getType() getScore(array getType())
        score += args get(1) getType() getScore(index getType())        
        if(reqType) {
            score += fDecl getReturnType() getScore(reqType)
        }
        
        return score
        
    }
    
    getType: func -> Type {
        return type
    }
    
    toString: func -> String {
        array toString() + "[" + index toString() + "]"
    }
    
    isReferencable: func -> Bool { true }
    
    replace: func (oldie, kiddo: Node) -> Bool {
        match oldie {
            case array => array = kiddo; true
            case index => index = kiddo; true
            case => false
        }
    }

}