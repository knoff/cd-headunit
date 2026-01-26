import { useState, useEffect } from 'react'

function App() {
    const [health, setHealth] = useState({ status: 'loading...', version: '?' })

    useEffect(() => {
        fetch('/api/health')
            .then(res => res.json())
            .then(data => setHealth(data))
            .catch(err => setHealth({ status: 'error', version: 'off' }))
    }, [])

    return (
        <div className="min-h-screen bg-background text-white flex flex-col items-center justify-center p-4">
            <div className="max-w-md w-full bg-neutral-900 border border-neutral-800 rounded-2xl p-8 shadow-2xl">
                <header className="mb-8 text-center">
                    <h1 className="text-3xl font-bold tracking-tight text-accent mb-2">
                        REBORN
                    </h1>
                    <p className="text-neutral-500 uppercase text-xs tracking-[0.2em]">
                        HeadUnit OS Interface
                    </p>
                </header>

                <main className="space-y-6">
                    <div className="flex items-center justify-between p-4 bg-black/40 rounded-xl border border-white/5">
                        <span className="text-neutral-400">System Status</span>
                        <span className={`font-mono text-sm px-2 py-1 rounded ${health.status === 'ok' ? 'text-green-400 bg-green-400/10' : 'text-yellow-400 bg-yellow-400/10'
                            }`}>
                            {health.status.toUpperCase()}
                        </span>
                    </div>

                    <div className="flex items-center justify-between p-4 bg-black/40 rounded-xl border border-white/5">
                        <span className="text-neutral-400">OS Version</span>
                        <span className="font-mono text-sm text-accent">
                            v{health.version}
                        </span>
                    </div>
                </main>

                <footer className="mt-12 pt-6 border-t border-neutral-800 text-center">
                    <button
                        className="w-full py-3 px-6 bg-accent/10 hover:bg-accent/20 border border-accent/30 text-accent rounded-xl transition-all active:scale-95 text-sm font-medium"
                        onClick={() => window.location.reload()}
                    >
                        Refresh Diagnostics
                    </button>
                </footer>
            </div>

            <div className="mt-8 text-neutral-600 text-[10px] uppercase tracking-widest">
                Coffee Digital © 2026
            </div>
        </div>
    )
}

export default App
