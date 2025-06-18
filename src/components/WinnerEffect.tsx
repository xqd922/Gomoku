import React, { useEffect, useState } from 'react';

interface WinnerEffectProps {
  isVisible: boolean;
}

const WinnerEffect: React.FC<WinnerEffectProps> = ({ isVisible }) => {
  const [particles, setParticles] = useState<Array<{
    id: number;
    x: number;
    y: number;
    speedX: number;
    speedY: number;
    color: string;
    rotation: number;
    width: number;
    height: number;
  }>>([]);

  useEffect(() => {
    if (!isVisible) {
      setParticles([]);
      return;
    }

    // 创建彩带粒子
    const colors = ['#ff0000', '#ffd700', '#00ff00', '#00ffff', '#ff69b4', '#ff8c00', '#9370db'];
    const newParticles = Array.from({ length: 80 }, (_, i) => ({
      id: i,
      x: 45 + Math.random() * 10, // 从中心位置开始，添加一些随机偏移
      y: 70, // 从70%的位置开始
      speedX: (Math.random() - 0.5) * 3, // 横向速度范围
      speedY: -Math.random() * 2.5 - 1.5, // 向上的初始速度
      color: colors[Math.floor(Math.random() * colors.length)],
      rotation: Math.random() * 360,
      width: 4 + Math.random() * 3, // 彩带宽度
      height: 15 + Math.random() * 8 // 彩带长度
    }));

    setParticles(newParticles);

    // 动画循环
    let animationFrame: number;
    const animate = () => {
      setParticles(prevParticles => 
        prevParticles.map(particle => ({
          ...particle,
          x: particle.x + particle.speedX,
          y: particle.y + particle.speedY,
          speedY: particle.speedY + 0.08, // 重力效果
          rotation: particle.rotation + particle.speedX * 3 // 旋转速度
        })).filter(particle => particle.y < 90 && particle.y > 0) // 限制彩带的运动范围
      );

      animationFrame = requestAnimationFrame(animate);
    };

    animate();

    return () => {
      cancelAnimationFrame(animationFrame);
    };
  }, [isVisible]);

  return (
    <div style={{
      position: 'absolute',
      top: 0,
      left: 0,
      width: '100%',
      height: '100%',
      pointerEvents: 'none',
      overflow: 'hidden'
    }}>
      {particles.map(particle => (
        <div
          key={particle.id}
          style={{
            position: 'absolute',
            left: `${particle.x}%`,
            top: `${particle.y}%`,
            width: `${particle.width}px`,
            height: `${particle.height}px`,
            backgroundColor: particle.color,
            transform: `translate(-50%, -50%) rotate(${particle.rotation}deg)`,
            opacity: Math.max(0, Math.min(1, (90 - particle.y) / 40)),
            transition: 'opacity 0.2s',
            boxShadow: '0 0 2px rgba(0,0,0,0.1)' // 轻微阴影增加层次感
          }}
        />
      ))}
    </div>
  );
};

export default WinnerEffect;