// Score Calculator
class ScoreCalculator {
    calculate(data) {
        let score = 50; // Base score
        const breakdown = { base: 50, adjustments: [] };

        // MX Score
        if (data.mx) {
            if (data.mx.valid) {
                score += 25;
                breakdown.adjustments.push({ category: 'mx', points: 25, reason: 'MX válido' });
            } else {
                score -= 15;
                breakdown.adjustments.push({ category: 'mx', points: -15, reason: 'MX inválido' });
            }
        }

        // Disposable Score
        if (data.disposable) {
            if (data.disposable.isDisposable) {
                score -= 40;
                breakdown.adjustments.push({ category: 'disposable', points: -40, reason: 'Email descartável' });
            } else {
                score += 15;
                breakdown.adjustments.push({ category: 'disposable', points: 15, reason: 'Não é descartável' });
            }
        }

        // Domain Score
        if (data.parsed) {
            const corporateDomains = ['gmail.com', 'outlook.com', 'yahoo.com', 'hotmail.com'];
            if (corporateDomains.includes(data.parsed.domain)) {
                score += 10;
                breakdown.adjustments.push({ category: 'domain', points: 10, reason: 'Domínio conhecido' });
            }
        }

        // Normalizar score (0-100)
        score = Math.max(0, Math.min(100, score));

        return {
            total: Math.round(score),
            breakdown: breakdown,
            quality: score >= 80 ? 'excellent' : score >= 60 ? 'good' : score >= 40 ? 'fair' : 'poor',
            recommendation: score >= 60 ? 'accept' : 'review'
        };
    }
}

module.exports = ScoreCalculator;
