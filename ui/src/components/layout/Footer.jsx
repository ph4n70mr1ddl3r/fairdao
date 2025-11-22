import React from 'react';

export function Footer() {
    return (
        <footer className="py-8 text-center text-fair-muted text-sm border-t border-white/5 mt-auto">
            <p>© 2025 FairDAO. All rights reserved.</p>
            <div className="flex justify-center gap-4 mt-2">
                <a href="#" className="hover:text-fair-primary transition-colors">Whitepaper</a>
                <a href="#" className="hover:text-fair-primary transition-colors">Twitter</a>
                <a href="#" className="hover:text-fair-primary transition-colors">GitHub</a>
            </div>
        </footer>
    );
}
