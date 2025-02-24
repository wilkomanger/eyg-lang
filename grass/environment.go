package main

type Env struct {
	key   string
	value Value
	next  *Env
}

func emptyEnv() *Env {
	return nil
}

func (env *Env) push(key string, value Value) *Env {
	return &Env{key, value, env}
}

func (env *Env) get(key string) (Value, bool) {
	if env == nil {
		return nil, false
	}
	if key == env.key {
		return env.value, true
	}
	return env.next.get(key)
}
